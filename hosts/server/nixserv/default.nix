{ flake, config, pkgs, lib, modulesPath, ... }: {
  imports = [
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

  environment.systemPackages = with pkgs; [
    attic-client
  ];

  users = {
    users = {
      builder = {
        isNormalUser = true;
        extraGroups = [ "trusted" ];
        home = "/var/lib/builder";
        openssh.authorizedKeys.keyFiles = builtins.map (system: builtins.elemAt system.config.users.users.root.openssh.authorizedKeys.keyFiles 0) (lib.attrValues flake.nixosConfigurations);
      };

      atticd = {
        uid = 949;
        group = "atticd";
        home = "/var/lib/atticd";
        useDefaultShell = true;
      };
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

        database = {
          url = "postgresql://attic@localhost:5432/attic";
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
    };

    caddy.virtualHosts = {
      cache.extraConfig = /*caddyfile*/ ''
        encode {
          zstd
          match {
            header Content-Type application/x-nix-archive
          }
        }

        reverse_proxy 127.0.0.1:8080
      '';
    };
  };

  systemd.services.postgresql.postStart = ''
    $PSQL -tA <<'EOF'
      DO $$
      DECLARE password TEXT;
      BEGIN
        password := trim(both from replace(pg_read_file('${config.sops.secrets.POSTGRESQL_PASSWORD.path}'), E'\n', '''));
        EXECUTE format('ALTER ROLE attic WITH PASSWORD '''%s''';', password);
      END $$;
    EOF
  '';

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
