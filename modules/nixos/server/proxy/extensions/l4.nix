{
  isThisIOPrimaryHost,
  collectAllAttrsFunc,
  getAllAttrsFunc,
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
    mkDefault
    mkIf
    mkMerge
    mkOption
    types
    flatten
    unique
    ;

  inherit (types)
    str
    port
    nullOr
    attrsOf
    submodule
    ;

  inherit (proxyLib) replaceLocalHost;
in
{
  options.server.proxy.virtualHosts = mkOption {
    type = attrsOf (
      submodule (_: {
        options.l4 = mkOption {
          default = null;
          type = nullOr (submodule {
            options = {
              listenPort = mkOption {
                type = port;
                description = "Port to listen on for L4 traffic.";
              };
              protocol = mkOption {
                type = types.enum [
                  "tcp"
                  "udp"
                ];
                default = "tcp";
                description = "Protocol for L4 listener.";
              };
              config = mkOption {
                type = str;
                default = "";
                description = "Configuration for the L4 plugin.";
              };
            };
          });
        };
      })
    );
  };

  config = mkMerge [
    {
      server.proxy.extensions.l4 = {
        priority = 10;
        consumesExtraConfig = false;
        enable = mkDefault (
          getAllAttrsFunc "server.proxy.virtualHosts" (
            virtualHosts: _: virtualHosts |> builtins.attrValues |> builtins.any (vh: vh.l4 != null)
          )
          |> builtins.any (x: x)
        );
        config =
          _name: _vh: _hostCfg:
          "";
        globalConfig =
          _hostCfg:
          let
            sanitiseMatcherName = name: builtins.replaceStrings [ "." "-" ] [ "_" "_" ] name;

            allL4Entries =
              collectAllAttrsFunc "server.proxy.virtualHosts" (
                virtualHosts: vhostHostCfg:
                virtualHosts
                |> builtins.attrValues
                |> builtins.filter (vh: vh.l4 != null)
                |> map (vh: {
                  inherit (vh) baseUrl;
                  port = vh.l4.listenPort;
                  config = replaceLocalHost vhostHostCfg.host.name vh.l4.config;
                })
              )
              |> flatten;

            groupedByPort = builtins.groupBy (entry: toString entry.port) allL4Entries;
          in
          if allL4Entries == [ ] then
            ""
          else
            ''
              layer4 {
                ${builtins.concatStringsSep "\n" (
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
                  )
                )}
              }
            '';
        vhostModule = null;
      };
    }

    (mkIf isThisIOPrimaryHost {
      networking.firewall = lib.mkIf config.server.proxy.extensions.l4.enable (
        let
          l4Entries =
            collectAllAttrsFunc "server.proxy.virtualHosts" (
              virtualHosts: _:
              builtins.attrValues virtualHosts
              |> builtins.filter (vh: vh.l4 != null)
              |> map (vh: {
                port = vh.l4.listenPort;
                protocol = vh.l4.protocol;
              })
            )
            |> flatten
            |> unique;
          tcpPorts = builtins.filter (e: e.protocol == "tcp") l4Entries |> map (e: e.port) |> unique;
          udpPorts = builtins.filter (e: e.protocol == "udp") l4Entries |> map (e: e.port) |> unique;
        in
        {
          allowedTCPPorts = tcpPorts;
          allowedUDPPorts = udpPorts;
        }
      );
    })
  ];
}
