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
      pve.extraConfig = ''
        reverse_proxy {
          to https://192.168.2.210:8006
          transport http {
            tls_insecure_skip_verify
          }
        }
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
      plugins = [ "github.com/mholt/caddy-l4@v0.0.0-20250530154005-4d3c80e89c5f" ];
      hash = "sha256-NLFl+ix36z6X1Anr1F6rdMPwSEysSVl84Ad71zprsbU=";
    };
    email = "admin@racci.dev";

    # Certs are handled by acme
    globalConfig = ''
      auto_https "disable_certs"
    '';

    logFormat = ''
      format console
    '';

    extraConfig = ''
      (cors) {
        @cors_preflight{args.0} method OPTIONS
        @cors{args.0} header Origin {args.0}

        handle @cors_preflight{args.0} {
          header {
            Access-Control-Allow-Origin "{args.0}"
            Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            Access-Control-Allow-Headers *
            Access-Control-Max-Age "3600"
            defer
          }
          respond "" 204
        }

        handle @cors{args.0} {
          header {
            Access-Control-Allow-Origin "{args.0}"
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
