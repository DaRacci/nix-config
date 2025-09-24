_:
{
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

  server.proxy = {
    domain = "racci.dev";
    virtualHosts = {
      pve.extraConfig = ''
        reverse_proxy {
          to https://192.168.2.210:8006
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';
    };
  };

  systemd.services.caddy = {
    after = [
      "tailscaled.service"
      "adguardhome.service"
    ];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = "5s";
    };
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/mholt/caddy-l4@v0.0.0-20250829174953-ad3e83c51edb"
        "github.com/WeidiDeng/caddy-cloudflare-ip@v0.0.0-20231130002422-f53b62aa13cb"
      ];
      hash = "sha256-xn/FcRcFx0MlKRNuMsuvcZMz+j1Mn1zM7J/c07bhOXU=";
    };
    email = "admin@racci.dev";

    # Certs are handled by acme
    globalConfig = ''
      auto_https "disable_certs"

      servers {
        trusted_proxies cloudflare
        trusted_proxies static private_ranges 110.174.120.26
        client_ip_headers X-Forwarded-For Cf-Connecting-Ip
      }
    '';

    logFormat = ''
      format console
    '';

    extraConfig = ''
      # Automatic Import for all Virtual Hosts
      (default) { }

      # Automatic Import for all Virtual Hosts with `server.proxy.virtualHosts.<name>.public = true`
      (public) { }

      (cors) {
        @cors_preflight{args[0]} method OPTIONS
        @cors{args[0]} header Origin {args[0]}

        handle @cors_preflight{args[0]} {
          header {
            Access-Control-Allow-Origin "{args[0]}"
            Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            Access-Control-Allow-Headers *
            Access-Control-Max-Age "3600"
            defer
          }
          respond "" 204
        }

        handle @cors{args[0]} {
          header {
            Access-Control-Allow-Origin "{args[0]}"
            Access-Control-Expose-Headers *
            defer
          }
        }
      }
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
