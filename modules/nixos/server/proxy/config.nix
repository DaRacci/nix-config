{
  isThisIOPrimaryHost,
  collectAllAttrs,
  collectAllAttrsFunc,
  proxyLib,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    flatten
    hasSuffix
    mapAttrs'
    mkIf
    mkMerge
    nameValuePair
    optionalString
    unique
    ;

  cfg = config.server.proxy;

  inherit (proxyLib) replaceLocalHost collectKanidmVirtualHosts resolveKanidmContext;

  # Sanitise a domain name into a valid Caddy matcher name (only alphanumeric and underscores)
  sanitiseMatcherName = name: builtins.replaceStrings [ "." "-" ] [ "_" "_" ] name;

  noAcmeCertsDomains =
    collectAllAttrs "server.proxy.virtualHosts"
    |> builtins.attrValues
    |> builtins.filter (vh: !vh.useAcmeCerts)
    |> map (vh: [ vh.baseUrl ] ++ vh.aliases)
    |> flatten;

  # Generate L4 config, grouping entries that share the same port into a single listener
  l4Config =
    let
      allL4Entries =
        collectAllAttrsFunc "server.proxy.virtualHosts" (
          virtualHosts: hostCfg:
          virtualHosts
          |> builtins.attrValues
          |> builtins.filter (vh: vh.l4 != null)
          |> map (vh: {
            inherit (vh) baseUrl;
            port = vh.l4.listenPort;
            config = replaceLocalHost hostCfg.host.name vh.l4.config;
          })
        )
        |> flatten;

      groupedByPort = builtins.groupBy (entry: toString entry.port) allL4Entries;
    in
    builtins.attrValues (
      builtins.mapAttrs (
        port: entries:
        if builtins.length entries == 1 then
          let
            entry = builtins.head entries;
          in
          ''
            ${entry.baseUrl}:${port} {
              ${entry.config}
            }
          ''
        else
          ''
            :${port} {
              ${builtins.concatStringsSep "\n" (
                map (entry: ''
                  @${sanitiseMatcherName entry.baseUrl} http host ${entry.baseUrl}
                  route @${sanitiseMatcherName entry.baseUrl} {
                    ${entry.config}
                  }
                '') entries
              )}
            }
          ''
      ) groupedByPort
    );

  emptyAllowGroupsHosts =
    collectKanidmVirtualHosts
    |> lib.filterAttrs (name: vh: (resolveKanidmContext name vh).allowGroups == [ ]);
in
{
  config = mkMerge [
    {
      assertions = [
        {
          assertion = emptyAllowGroupsHosts == { };
          message = "server.proxy.virtualHosts: kanidm.allowGroups cannot be empty for: ${builtins.concatStringsSep ", " (builtins.attrNames emptyAllowGroupsHosts)}";
        }
      ];
    }

    (mkIf (!isThisIOPrimaryHost) {
      server.network.openPortsForSubnet.tcp =
        cfg.virtualHosts |> builtins.attrValues |> map (vh: vh.ports) |> flatten |> unique;
    })

    (mkIf isThisIOPrimaryHost {
      services.caddy = {
        globalConfig = ''
          layer4 {
            ${builtins.concatStringsSep "\n" l4Config}
          }
        '';

        virtualHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
          virtualHosts: hostCfg:
          mapAttrs' (
            name: vh:
            let
              additionalPortAliases =
                vh.listenPorts
                |> lib.lists.drop 1
                |> map (port: map (listenDomain: "${listenDomain}:${toString port}") ([ vh.baseUrl ] ++ vh.aliases))
                |> flatten;
              hostName = "${vh.baseUrl}:${toString (builtins.head vh.listenPorts)}";
            in
            nameValuePair hostName {
              inherit hostName;
              useACMEHost = if !vh.useAcmeCerts then null else vh.baseUrl;
              serverAliases = vh.aliases ++ additionalPortAliases;
              extraConfig = ''
                import default
                ${optionalString vh.public "import public"}
                ${optionalString (vh.kanidm != null) ''
                  ${optionalString (vh.kanidm.bypassPaths != [ ]) ''
                    @bypass_auth_${
                      builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name
                    } path ${builtins.concatStringsSep " " vh.kanidm.bypassPaths}
                    handle @bypass_auth_${builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name} {
                      ${replaceLocalHost hostCfg.host.name vh.extraConfig}
                    }
                  ''}
                  route /auth/* {
                    authenticate with ${name}_portal
                  }
                  handle {
                    authorize with ${name}_policy
                    ${replaceLocalHost hostCfg.host.name vh.extraConfig}
                  }
                ''}
                ${optionalString (vh.kanidm == null) (replaceLocalHost hostCfg.host.name vh.extraConfig)}
              '';
            }
          ) virtualHosts
        );
      };

      security.acme.certs =
        config.services.caddy.virtualHosts
        |> lib.filterAttrs (
          name: _: hasSuffix ".${cfg.domain}" name && !builtins.elem name noAcmeCertsDomains
        )
        |> lib.mapAttrs (
          name: vh: {
            extraDomainNames = vh.serverAliases;
          }
        );

      networking.firewall =
        let
          l4Ports =
            collectAllAttrsFunc "server.proxy.virtualHosts" (
              virtualHosts: _:
              builtins.attrValues virtualHosts
              |> builtins.filter (vh: vh.l4 != null)
              |> map (vh: vh.l4.listenPort)
            )
            |> flatten
            |> unique;
        in
        {
          allowedTCPPorts = l4Ports;
          allowedUDPPorts = l4Ports;
        };
    })
  ];
}
