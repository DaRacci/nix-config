{
  config,
  pkgs,
  ...
}:
let
  atticOwned = {
    owner = config.services.atticd.user;
    inherit (config.services.atticd) group;
  };
in
{
  sops.secrets = {
    ATTIC_ENVIRONMENT = atticOwned;
  };

  server = {
    database.postgres.attic = {
      password = atticOwned;
    };

    dashboard = {
      icon = "mdi-cached";
      items.cache = {
        title = "Attic Cache";
        icon = "sh-nixos";
      };
    };

    proxy.virtualHosts = {
      cache.extraConfig = ''
        encode {
          zstd
          match {
            header Content-Type application/x-nix-archive
          }
        }

        reverse_proxy http://127.0.0.1:8080
      '';
    };
  };

  environment.systemPackages = with pkgs; [ attic-client ];

  users = {
    users.atticd = {
      uid = 949;
      group = "atticd";
      home = "/var/lib/atticd";
      useDefaultShell = true;
    };

    groups.atticd = {
      gid = 949;
    };
  };

  services = {
    atticd = {
      enable = true;
      package = pkgs.attic-server;
      environmentFile = config.sops.secrets.ATTIC_ENVIRONMENT.path;
      settings = {
        listen = "[::]:8080";
        allowed-hosts = [ ];
        api-endpoint = "https://cache.racci.dev/";
        soft-delete-caches = false;
        require-proof-of-possession = true;

        database =
          let
            db = config.server.database.postgres.attic;
          in
          {
            url = "postgresql://${db.user}@${db.host}:${toString db.port}/${db.database}";
            heartbeat = true;
          };

        storage = {
          type = "s3";
          region = "us-east-1";
          bucket = "attic";
          endpoint = "https://minio.racci.dev";
        };

        chunking = {
          nar-size-threshold = 64 * 1024;
          min-size = 16 * 1024;
          avg-size = 64 * 1024;
          max-size = 256 * 1024;
        };

        compression = {
          type = "zstd"; # TODO Maybe use brotli instead?
          level = 8;
        };

        garbage-collection = {
          interval = "12 hours";
          default-retention-period = "14 days";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
