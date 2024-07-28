{ inputs, config, pkgs, modulesPath, ... }: {
  imports = [
    inputs.attic.nixosModules.atticd
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  sops.secrets = {
    ATTIC_ENVIRONMENT = {
      owner = config.services.atticd.user;
      inherit (config.services.atticd) group;
    };
    POSTGRESQL_PASSWORD = {
      owner = "postgres";
      group = "postgres";
    };
  };

  environment.systemPackages = with pkgs.unstable; [
    attic-client
  ];

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

  services = rec {
    atticd = {
      enable = true;
      package = pkgs.unstable.attic-server;
      credentialsFile = config.sops.secrets.ATTIC_ENVIRONMENT.path;
      settings = {
        listen = "127.0.0.1:8080";
        allowed-hosts = [ ];
        api-endpoint = "https://cache.racci.dev/";
        soft-delete-caches = false;
        require-proof-of-possession = true;

        database = {
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

    postgresql = {
      enable = true;
      ensureDatabases = [ "attic" ];
      ensureUsers = [{ name = "attic"; ensureDBOwnership = true; }];

      initialScript = pkgs.writeText "init-script" ''
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${config.sops.secrets.POSTGRESQL_PASSWORD.path}'), E'\n', '''));
          EXECUTE format('ALTER ROLE attic WITH PASSWORD '''%s''';', password);
        END $$;
      '';
    };

    caddy.virtualHosts = {
      cache.extraConfig = /*caddyfile*/ ''
        encode {
          zstd
          match {
            header Content-Type application/x-nix-archive
          }
        }

        reverse_proxy ${atticd.settings.listen}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
