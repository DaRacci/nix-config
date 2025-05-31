{
  isNixio,
  getNixioConfig,
  ...
}:
{
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption mkDefault types;
  cfg = config.server.proxy;

  serverConfigurations = lib.trivial.pipe self.nixosConfigurations [
    builtins.attrValues
    (builtins.map (host: host.config))
    (builtins.filter (config: config.host.device.role == "server"))
    (builtins.filter (
      config: config.server.proxy ? virtualHosts && config.server.proxy.virtualHosts != { }
    ))
  ];

  replaceLocalHost =
    host: str:
    if host == "nixio" then
      str
    else
      builtins.replaceStrings [
        "localhost"
        "0.0.0.0"
        "127.0.0.1"
        "[::]"
        "[::1]"
        "::1"
      ] (builtins.genList (_: host) 6) str;
in
{
  options.server.proxy = with types; {
    domain = mkOption {
      type = str;
      description = ''
        The base domain for all virtual hosts.
      '';
    };

    virtualHosts = mkOption {
      description = ''
        Virtual hosts to be handled by the NixIO server and forwarded to the respective backend.

        All virtual hosts are also added to acme for automatic certificate management.

        Each virtual host will have the value configured in <server.proxy.domain> added as the basedomain,
        with this attributes name as the subdomain.

        Defining virtualHosts on any machine except NixIO will do nothing on that machine but are instead aggregated on NixIO.
      '';
      default = { };
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              baseUrl = mkOption {
                type = str;
                default = "${name}.${getNixioConfig "server.proxy.domain"}";
                description = ''
                  The base url including the configured base domain name.
                '';
                readOnly = true;
              };

              extraConfig = mkOption {
                type = str;
                description = ''
                  Configuration to be placed in `<services.caddy.virtualHosts.${name}.extraConfig>`

                  This configuration is parsed and the following are applied to the content:
                  - Rewrite localhost/127.0.0.1/0.0.0.0 to the machines domain name.
                '';
              };

              l4 = mkOption {
                default = null;
                type = nullOr (submodule {
                  options = {
                    listenPort = mkOption {
                      type = types.port;
                      default = null;
                      description = "Port to listen on for L4 traffic";
                    };

                    config = mkOption {
                      type = str;
                      default = "";
                      description = "Configuration for the L4 plugin";
                    };
                  };
                });
              };
            };
          }
        )
      );
    };
  };

  config = {
    server.dashboard.items = lib.pipe cfg.virtualHosts [
      (builtins.mapAttrs (
        name: cfg: {
          title = mkDefault name;
          url = mkDefault "https://${cfg.baseUrl}/";
          icon = mkDefault "auto-fetched";
        }
      ))
    ];

    services.caddy = lib.mkIf isNixio {
      globalConfig = ''
          layer4 {
            ${lib.pipe serverConfigurations [
              (builtins.filter (cfg: cfg.server.proxy ? virtualHosts && cfg.server.proxy.virtualHosts != { }))
              (builtins.map (
                cfg:
                lib.pipe cfg.server.proxy.virtualHosts [
                  builtins.attrValues
                  (builtins.filter (vh: vh.l4 != null))
                  (builtins.map (
                    vh:
                    lib.mine.attrsets.recursiveMergeAttrs [
                      vh
                      {
                        l4.config = replaceLocalHost cfg.host.name vh.l4.config;
                      }
                    ]
                  ))
                ]
              ))
              lib.flatten
              (builtins.map (cfg: ''
                ${cfg.baseUrl}:${toString cfg.l4.listenPort} {
                  ${cfg.l4.config}
                }
              ''))
              lib.flatten
              (builtins.concatStringsSep "\n")
            ]}
        }
      '';

      virtualHosts = lib.pipe serverConfigurations [
        (builtins.map (
          config:
          (lib.mapAttrs' (
            _: value:
            lib.nameValuePair value.baseUrl {
              hostName = value.baseUrl;
              useACMEHost = value.baseUrl;
              extraConfig = replaceLocalHost config.host.name value.extraConfig;
            }
          ) config.server.proxy.virtualHosts)
        ))
        lib.mergeAttrsList
      ];
    };

    security.acme.certs = lib.mkIf isNixio (
      lib.pipe config.services.caddy.virtualHosts [
        builtins.attrNames
        (builtins.filter (name: lib.strings.hasSuffix ".${cfg.domain}" name))
        (map (name: lib.nameValuePair name { }))
        builtins.listToAttrs
      ]
    );
  };
}
