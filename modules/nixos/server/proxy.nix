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
              public = mkOption {
                type = bool;
                default = false;
                description = ''
                  When enabled this service will be accessible to the public via Cloudflared Tunnels.
                  Traffic will still be routed through caddy.
                '';
              };

              baseUrl = mkOption {
                type = str;
                default = "${name}.${getNixioConfig "server.proxy.domain"}";
                description = ''
                  The base url including the configured base domain name.
                '';
                readOnly = true;
              };

              ports = mkOption {
                type = types.listOf types.port;
                default = [ ];
                description = ''
                  Ports to be opened from the host for NixIO to forward traffic to.

                  These ports will only accept traffic from the defined subnets for security.
                '';
              };

              extraConfig = mkOption {
                type = nullOr str;
                default = null;
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
          icon = mkDefault "sh-${name}"; # Guess an icon name, should work for most common services
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
              extraConfig =
                [
                  "import default"
                  (lib.optionalString (value.public) "import public")
                  (lib.optionalString (value.extraConfig != null) (
                    replaceLocalHost config.host.name value.extraConfig
                  ))
                ]
                |> builtins.concatStringsSep "\n";
            }
          ) config.server.proxy.virtualHosts)
        ))
        lib.mergeAttrsList
      ];
    };

    services.cloudflared.tunnels."8d42e9b2-3814-45ea-bbb5-9056c8f017e2" =
      let
        publicHosts =
          serverConfigurations
          |> builtins.map (config: config.server.proxy.virtualHosts)
          |> lib.mergeAttrsList
          |> lib.filterAttrs (_: vh: vh.public)
          |> lib.mapAttrs' (_: vh: lib.nameValuePair vh.baseUrl "https://${vh.baseUrl}");
      in
      lib.mkIf ((builtins.attrValues publicHosts |> builtins.length) > 0) {
        ingress = publicHosts;
      };

    security.acme.certs = lib.mkIf isNixio (
      lib.pipe config.services.caddy.virtualHosts [
        builtins.attrNames
        (builtins.filter (name: lib.strings.hasSuffix ".${cfg.domain}" name))
        (map (name: lib.nameValuePair name { }))
        builtins.listToAttrs
      ]
    );

    networking.firewall =
      let
        allCombinations =
          cfg.virtualHosts
          |> builtins.attrValues
          |> builtins.map (vh: vh.ports)
          |> lib.flatten
          |> builtins.map (
            port:
            builtins.map (
              subnet:
              subnet
              // {
                inherit port;
              }
            ) config.server.network.subnets
          )
          |> lib.flatten;

        allPorts = allCombinations |> builtins.map (v: v.port) |> lib.unique;
      in
      {
        allowedTCPPorts = lib.mkIf isNixio allPorts;
        allowedUDPPorts = lib.mkIf isNixio allPorts;

        extraCommands = lib.mkIf (!isNixio) (
          allCombinations
          |> builtins.map (
            v:
            ''
              iptables -A nixos-fw -p tcp --source ${v.ipv4.cidr} --dport ${toString v.port} -j nixos-fw-accept
              iptables -A nixos-fw -p udp --source ${v.ipv4.cidr} --dport ${toString v.port} -j nixos-fw-accept
            ''
            + (lib.optionalString (v.ipv6.cidr != null) ''
              ip6tables -A nixos-fw -p tcp --source ${v.ipv6.cidr} --dport ${toString v.port} -j nixos-fw-accept
              ip6tables -A nixos-fw -p udp --source ${v.ipv6.cidr} --dport ${toString v.port} -j nixos-fw-accept
            '')
          )
          |> builtins.concatStringsSep "\n"
        );

        extraStopCommands = lib.mkIf (!isNixio) (
          allCombinations
          |> builtins.map (
            v:
            ''
              iptables -D nixos-fw -p tcp --source ${v.ipv4.cidr} --dport ${toString v.port} -j nixos-fw-accept || true
              iptables -D nixos-fw -p udp --source ${v.ipv4.cidr} --dport ${toString v.port} -j nixos-fw-accept || true
            ''
            + (lib.optionalString (v.ipv6.cidr != null) ''
              ip6tables -D nixos-fw -p tcp --source ${v.ipv6.cidr} --dport ${toString v.port} -j nixos-fw-accept || true
              ip6tables -D nixos-fw -p udp --source ${v.ipv6.cidr} --dport ${toString v.port} -j nixos-fw-accept || true
            '')
          )
          |> builtins.concatStringsSep "\n"
        );
      };
  };
}
