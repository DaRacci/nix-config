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

  server = {
    dashboard.items.pve = {
      title = "Proxmox VE";
      icon = "sh-proxmox";
    };

    proxy = {
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
  };

  systemd.services = {
    caddy = rec {
      after = [
        "tailscaled.service"
        "adguardhome.service"
      ];
      wants = after;
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "5s";
        RestartPreventExitStatus = lib.mkForce null;
      };
    };
    upgrade-status = rec {
      after = [ "caddy.service" ];
      wants = after;
    };
    hacompanion = rec {
      after = [ "caddy.service" ];
      wants = after;
    };
  };

  services.caddy = {
    enable = true;
    # TODO - Implement auto update for plugins
    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/mholt/caddy-l4@v0.0.0-20251124224044-66170bec9f4d"
        "github.com/WeidiDeng/caddy-cloudflare-ip@v0.0.0-20231130002422-f53b62aa13cb"
        "github.com/greenpau/caddy-security@v1.1.31"
      ];
      hash = "sha256-BUn7yOl/srGSGWjFqSlWa93O3rKt7XNU0W0eiO5USAY=";
    };
    email = "admin@racci.dev";

    globalConfig = ''
      # Certs are handled by acme
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
      (default) {
        # Allow embedding in iframes for specific hosts
        header {
          X-Frame-Options "ALLOW-FROM https://dashboard.racci.dev"
          Content-Security-Policy "frame-ancestors 'self' https://dashboard.racci.dev"
        }
      }

      # Automatic Import for all Virtual Hosts with `server.proxy.virtualHosts.<name>.public = true`
      (public) {
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
          X-XSS-Protection "1; mode=block"
          -Server
        }
      }

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
