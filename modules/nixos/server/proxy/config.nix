{
  isThisIOPrimaryHost,
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
            ${
              collectAllAttrsFunc "server.proxy.virtualHosts" (
                virtualHosts: hostCfg:
                virtualHosts
                |> builtins.attrValues
                |> builtins.filter (vh: vh.l4 != null)
                |> builtins.map (vh: ''
                  ${vh.baseUrl}:${toString vh.l4.listenPort} {
                    ${replaceLocalHost hostCfg.host.name vh.l4.config}
                  }
                '')
              )
              |> builtins.concatStringsSep "\n"
            }
          }
        '';

        virtualHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
          virtualHosts: hostCfg:
          mapAttrs' (
            name: vh:
            nameValuePair vh.baseUrl {
              hostName = vh.baseUrl;
              useACMEHost = vh.baseUrl;
              serverAliases = vh.aliases;
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
        |> lib.filterAttrs (name: _: hasSuffix ".${cfg.domain}" name)
        |> lib.mapAttrs (
          _name: vh: {
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
