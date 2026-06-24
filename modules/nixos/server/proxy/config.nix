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
    unique
    ;

  cfg = config.server.proxy;

  inherit (proxyLib)
    replaceLocalHost
    collectKanidmVirtualHosts
    resolveKanidmContext
    getExtensionsForVhost
    getGlobalConfigFromExtensions
    ;

  noAcmeCertsDomains =
    collectAllAttrs "server.proxy.virtualHosts"
    |> builtins.attrValues
    |> builtins.filter (vh: !vh.useAcmeCerts)
    |> map (vh: [ vh.baseUrl ] ++ vh.aliases)
    |> flatten;

  emptyAllowGroupsHosts =
    collectKanidmVirtualHosts
    |> lib.filterAttrs (name: vh: (resolveKanidmContext name vh).allowGroups == [ ]);

  allExtensionNames = builtins.attrNames config.server.proxy.extensions;

  enabledExtensions =
    lib.mapAttrsToList (_name: extVal: extVal // { inherit _name; }) config.server.proxy.extensions
    |> builtins.filter (ext: ext.enable);

  invalidExtensionRefs = builtins.concatLists (
    builtins.attrValues config.server.proxy.virtualHosts
    |> builtins.filter (vh: vh.extensions != null)
    |> map (vh: builtins.filter (extName: !builtins.elem extName allExtensionNames) vh.extensions)
  );

  vhostsWithMultipleConsumers = builtins.filter (
    vh:
    let
      exts =
        if vh.extensions == null then
          enabledExtensions
        else
          builtins.filter (ext: builtins.elem ext._name vh.extensions) enabledExtensions;
      consumers = builtins.filter (ext: ext.consumesExtraConfig) exts;
    in
    builtins.length consumers > 1
  ) (builtins.attrValues config.server.proxy.virtualHosts);

  vhostsWithKanidmMissingExt =
    builtins.attrValues config.server.proxy.virtualHosts
    |> builtins.filter (
      vh: vh.kanidm != null && vh.extensions != null && !builtins.elem "kanidm" vh.extensions
    );
in
{
  config = mkMerge [
    {
      assertions = [
        {
          assertion = emptyAllowGroupsHosts == { };
          message = "server.proxy.virtualHosts: kanidm.allowGroups cannot be empty for: ${builtins.concatStringsSep ", " (builtins.attrNames emptyAllowGroupsHosts)}";
        }
        {
          assertion = invalidExtensionRefs == [ ];
          message = "server.proxy.virtualHosts: extension whitelist references nonexistent extensions: ${builtins.concatStringsSep ", " (lib.unique invalidExtensionRefs)}";
        }
        {
          assertion = vhostsWithMultipleConsumers == [ ];
          message = "server.proxy.virtualHosts: vhosts have multiple extensions with consumesExtraConfig=true: ${
            builtins.concatStringsSep ", " (map (vh: vh._name) vhostsWithMultipleConsumers)
          }";
        }
        {
          assertion = vhostsWithKanidmMissingExt == [ ];
          message = "server.proxy.virtualHosts: vhost has kanidm enabled but extensions doesn't include kanidm: ${
            builtins.concatStringsSep ", " (map (vh: vh._name) vhostsWithKanidmMissingExt)
          }";
        }
      ];
    }

    (mkIf (!isThisIOPrimaryHost) {
      server.network.openPortsForSubnet.tcp =
        cfg.virtualHosts
        |> builtins.attrValues
        |> map (vh: vh.ports)
        |> flatten
        |> unique;
    })

    (mkIf isThisIOPrimaryHost {
      services.caddy = {
        globalConfig = getGlobalConfigFromExtensions config;

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
              logFormat = ''
                output file ${config.services.caddy.logDir}/access-${
                  lib.replaceStrings [ "/" " " ] [ "_" "_" ] hostName
                }.log {
                  mode 0640 # Group access for alloy to read logs.
                }
              '';
              extraConfig =
                let
                  resolvedExtraConfig = replaceLocalHost hostCfg.host.name vh.extraConfig;
                  vhWithResolvedExtra = vh // {
                    _resolvedExtraConfig = resolvedExtraConfig;
                  };
                  exts = getExtensionsForVhost name vhWithResolvedExtra hostCfg;
                  extResults = map (ext: {
                    name = ext._name;
                    output = ext.config name vhWithResolvedExtra hostCfg;
                    consumes = ext.consumesExtraConfig;
                  }) exts;
                  extOutputsStr = builtins.concatStringsSep "\n" (
                    map (r: r.output) (builtins.filter (r: r.output != "") extResults)
                  );
                  anyConsumerWithOutput = builtins.any (r: r.consumes && r.output != "") extResults;
                in
                ''
                  import default
                  ${extOutputsStr}
                  ${if anyConsumerWithOutput then "" else resolvedExtraConfig}
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
          _name: vh: {
            extraDomainNames = vh.serverAliases;
          }
        );

    })
  ];
}
