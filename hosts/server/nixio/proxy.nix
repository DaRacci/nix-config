_:
{
  config,
  pkgs,
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

  server.proxy = {
    domain = "racci.dev";
    virtualHosts = {
      minio.extraConfig = ''
        redir /console /console/

        handle_path /console* {
          reverse_proxy http://localhost${config.services.minio.consoleAddress}
        }

        reverse_proxy {
          to http://localhost${config.services.minio.listenAddress}
        }
      '';

      pve.extraConfig = ''
        reverse_proxy {
          to https://192.168.2.210:8006
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';

      # TODO - move out of dockge
      finance.extraConfig = ''
        reverse_proxy http://dockge:3000
      '';

      # TODO - replace with komodo & run off a nix machine
      dockge.extraConfig = ''
        reverse_proxy http://dockge:5001
      '';

      pgadmin.extraConfig = ''
        reverse_proxy http://localhost:${toString config.services.pgadmin.port}
      '';
    };
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/mholt/caddy-l4@master" ];
      hash = "sha256-Jj/3L6grkUuSz96qYxpm1X/PuzPouUGxqXfrPeprzr8=";
    };
    email = "admin@racci.dev";

    # Certs are handled by acme
    globalConfig = ''
      auto_https "disable_certs"
    '';

    logFormat = ''
      format console
    '';
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
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
