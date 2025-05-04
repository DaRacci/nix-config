{
  isNixio,
  getNixioConfig,
  ...
}:
{
  flake,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption mkDefault types;
  cfg = config.server.proxy;

  serverConfigurations = lib.trivial.pipe flake.nixosConfigurations [
    builtins.attrValues
    (builtins.map (host: host.config))
    (builtins.filter (config: config.host.device.role == "server"))
    (builtins.filter (
      config: config.server.proxy ? virtualHosts && config.server.proxy.virtualHosts != { }
    ))
  ];
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
      # Aggregate virtualHosts & Updates references to localhost in extraConfig & changes the attr name to the baseUrl.
      virtualHosts = lib.pipe serverConfigurations [
        (builtins.map (
          config:
          (lib.mapAttrs' (
            _: value:
            lib.nameValuePair value.baseUrl {
              hostName = value.baseUrl;
              useACMEHost = value.baseUrl;
              extraConfig =
                if config.host.name == "nixio" then
                  value.extraConfig
                else
                  builtins.replaceStrings [
                    "localhost"
                    "0.0.0.0"
                    "127.0.0.1"
                    "::1"
                  ] (builtins.genList (_: config.system.name) 4) value.extraConfig;
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
