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
          assertion =
            let
              allExtensionNames = builtins.attrNames config.server.proxy.extensions;
              invalidRefs = builtins.concatLists (
                builtins.attrValues config.server.proxy.virtualHosts
                |> builtins.filter (vh: vh.extensions != null)
                |> map (vh: builtins.filter (extName: !builtins.elem extName allExtensionNames) vh.extensions)
              );
            in
            invalidRefs == [ ];
          message = "server.proxy.virtualHosts: extension whitelist references nonexistent extensions: ${
            let
              allExtensionNames = builtins.attrNames config.server.proxy.extensions;
              invalidRefs = builtins.concatLists (
                builtins.attrValues config.server.proxy.virtualHosts
                |> builtins.filter (vh: vh.extensions != null)
                |> map (vh: builtins.filter (extName: !builtins.elem extName allExtensionNames) vh.extensions)
              );
            in
            builtins.concatStringsSep ", " (lib.unique invalidRefs)
          }";
        }
        {
          assertion =
            let
              vhostsWithMultipleConsumers = builtins.filter (
                vh:
                let
                  exts =
                    if vh.extensions == null then
                      builtins.attrValues config.server.proxy.extensions |> builtins.filter (ext: ext.enable)
                    else
                      builtins.filter (ext: builtins.elem ext._name vh.extensions) (
                        builtins.attrValues config.server.proxy.extensions |> builtins.filter (ext: ext.enable)
                      );
                  consumers = builtins.filter (ext: ext.consumesExtraConfig) exts;
                in
                builtins.length consumers > 1
              ) (builtins.attrValues config.server.proxy.virtualHosts);
            in
            vhostsWithMultipleConsumers == [ ];
          message = "server.proxy.virtualHosts: vhosts have multiple extensions with consumesExtraConfig=true: ${
            let
              vhostsWithMultipleConsumers = builtins.filter (
                vh:
                let
                  exts =
                    if vh.extensions == null then
                      builtins.attrValues config.server.proxy.extensions |> builtins.filter (ext: ext.enable)
                    else
                      builtins.filter (ext: builtins.elem ext._name vh.extensions) (
                        builtins.attrValues config.server.proxy.extensions |> builtins.filter (ext: ext.enable)
                      );
                  consumers = builtins.filter (ext: ext.consumesExtraConfig) exts;
                in
                builtins.length consumers > 1
              ) (builtins.attrValues config.server.proxy.virtualHosts);
            in
            builtins.concatStringsSep ", " (map (vh: vh._name) vhostsWithMultipleConsumers)
          }";
        }
        {
          assertion =
            let
              vhostsWithKanidmEmptyExtensions =
                builtins.attrValues config.server.proxy.virtualHosts
                |> builtins.filter (vh: vh.kanidm != null && vh.extensions == [ ]);
            in
            vhostsWithKanidmEmptyExtensions == [ ];
          message = "server.proxy.virtualHosts: vhost has kanidm enabled but extensions set to [] (kanidm auth won't be generated): ${
            let
              vhostsWithKanidmEmptyExtensions =
                builtins.attrValues config.server.proxy.virtualHosts
                |> builtins.filter (vh: vh.kanidm != null && vh.extensions == [ ]);
            in
            builtins.concatStringsSep ", " (map (vh: vh._name) vhostsWithKanidmEmptyExtensions)
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
                  ${optionalString vh.public "import public"}
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
