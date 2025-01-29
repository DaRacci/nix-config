{ mkVirtualHost, ... }:
{
  flake,
  config,
  pkgs,
  lib,
  ...
}:
{
  # Caddy group has access to certs, and minio needs access to its own certs.
  users.users.minio.extraGroups = [ "caddy" ];

  sops.secrets = {
    "CLOUDFLARE/EMAIL" = { };
    "CLOUDFLARE/DNS_API_TOKEN" = { };
    "CLOUDFLARE/ZONE_API_TOKEN" = { };
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy;
    email = "admin@racci.dev";

    globalConfig = ''
      auto_https "disable_certs"
    '';

    logFormat = ''
      format console
    '';

    # Create a map of virtual hosts using the configurations from other servers.
    # This will iterate the hosts of the flake and pull the virtualHosts configuration from each server.
    virtualHosts =
      lib.trivial.pipe flake.nixosConfigurations [
        # Exclude the current host
        (lib.filterAttrs (name: _: name != config.system.name))
        # Extract the config from each host
        builtins.attrValues
        (builtins.map (host: host.config))
        # Filter to only servers
        (builtins.filter (config: config.host.device.role == "server"))
        # Filter to only servers with at least one caddy virtualHost
        (builtins.filter (
          config: config.services.caddy ? virtualHosts && config.services.caddy.virtualHosts != { }
        ))
        # Update references in extraConfig to 127.0.0.1 or localhost to the hosts name,
        # Append the domain to the name, and enable the use of ACME provided certs.
        (builtins.map (
          config:
          lib.mapAttrs' (
            name: value:
            lib.nameValuePair "${name}.racci.dev" rec {
              hostName = "${name}.racci.dev";
              useACMEHost = hostName;
              extraConfig =
                builtins.replaceStrings
                  [ "0.0.0.0" "127.0.0.1" "localhost" ]
                  [
                    config.system.name
                    config.system.name
                    config.system.name
                  ]
                  value.extraConfig;
            }
            // value
          ) config.services.caddy.virtualHosts
        ))
        # Merge all the virtualHosts into a single map
        lib.mergeAttrsList
      ]
      // (lib.listToAttrs [
        (mkVirtualHost "minio" {
          extraConfig = ''
            redir /console /console/

            handle_path /console* {
              reverse_proxy http://localhost${config.services.minio.consoleAddress}
            }

            reverse_proxy {
              to http://localhost${config.services.minio.listenAddress}
            }
          '';
        })
        (mkVirtualHost "pve" {
          extraConfig = ''
            reverse_proxy {
              to https://192.168.2.210:8006
              transport http {
                tls_insecure_skip_verify
              }
            }
          '';
        })
        # TODO - move out of dockge
        (mkVirtualHost "finance" {
          extraConfig = ''
            reverse_proxy http://dockge:3000
          '';
        })
        # TODO - will this be needed in the future?
        (mkVirtualHost "dockge" {
          extraConfig = ''
            reverse_proxy http://dockge:5001
          '';
        })
        (mkVirtualHost "pgadmin" {
          extraConfig = ''
            reverse_proxy http://localhost:${toString config.services.pgadmin.port}
          '';
        })
      ]);
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@racci.dev";
      dnsResolver = "1.1.1.1:53";
      dnsProvider = "cloudflare";
      credentialFiles = {
        CLOUDFLARE_EMAIL_FILE = config.sops.secrets."CLOUDFLARE/EMAIL".path;
        CLOUDFLARE_DNS_API_TOKEN_FILE = config.sops.secrets."CLOUDFLARE/DNS_API_TOKEN".path;
        CLOUDFLARE_ZONE_API_TOKEN_FILE = config.sops.secrets."CLOUDFLARE/ZONE_API_TOKEN".path;
      };
    };

    certs = lib.trivial.pipe config.services.caddy.virtualHosts [
      builtins.attrNames
      (builtins.filter (name: lib.strings.hasSuffix ".racci.dev" name))
      (map (name: lib.nameValuePair name { }))
      builtins.listToAttrs
    ];
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
