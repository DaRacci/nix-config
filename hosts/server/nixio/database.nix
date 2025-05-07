{ subnets, fromAllServers, ... }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # For backups to be placed in the minio data directory.
  users.users.postgres.extraGroups = [ "minio" ];

  sops.secrets =
    {
      COUCHDB_SETTINGS = {
        owner = config.users.users.couchdb.name;
        group = config.users.groups.couchdb.name;
        restartUnits = [ "couchdb.service" ];
      };

      PGADMIN_PASSWORD = {
        owner = config.users.users.pgadmin.name;
        group = config.users.groups.pgadmin.name;
        restartUnits = [ "pgadmin.service" ];
      };

      "POSTGRES/POSTGRES_PASSWORD" = {
        owner = config.users.users.postgres.name;
        group = config.users.groups.postgres.name;
        restartUnits = [
          "postgresql.service"
          "pgadmin.service"
        ];
        mode = "0440";
      };
    }
    // fromAllServers [
      (builtins.map (config: config.sops.secrets))
      lib.mergeAttrsList
      (lib.filterAttrs (
        name: secret: lib.strings.hasPrefix "POSTGRES/" secret.name && lib.hasSuffix "_PASSWORD" secret.name
      ))
      (builtins.mapAttrs (
        _: value:
        (builtins.removeAttrs value [ "sopsFileHash" ])
        // {
          sopsFile = config.sops.defaultSopsFile;
          # Update owner and groups because it will always be only postgres on this server.
          owner = config.users.users.postgres.name;
          group = config.users.groups.postgres.name;
          # TODO - do i need to clean up the reload services?
        }
      ))
    ];

  server.database.postgres = {
    postgres = { };
  };

  services = {
    couchdb = {
      enable = true;
      package = pkgs.couchdb3;
      bindAddress = "0.0.0.0";
      extraConfigFiles = [
        config.sops.secrets."COUCHDB_SETTINGS".path
      ];
    };

    postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      enableJIT = true;
      enableTCPIP = true;

      extensions = ps: with ps; [ system_stats ];

      authentication = lib.mkOverride 10 (
        ''
          # TYPE  DATABASE  USER  ADDRESS   AUTH-METHOD   [AUTH-OPTIONS]
          local   all       all             peer
          local   all       all             scram-sha-256
        ''
        + (lib.pipe subnets [
          (builtins.map (
            subnet:
            [ "host  all  all  ${subnet.ipv4_cidr}  scram-sha-256" ]
            ++ lib.optionals (subnet.ipv6_cidr != null) [ "host  all  all  ${subnet.ipv6_cidr}  scram-sha-256" ]
          ))
          lib.flatten
          (builtins.concatStringsSep "\n")
        ])
      );

      settings = {
        password_encryption = "scram-sha-256";

        # IDK how this works so just copying over it from immich for now.
        search_path = "\"$user\", public, vectors";
      };
    };

    postgresqlBackup = {
      enable = true;
      compression = "zstd";
      compressionLevel = 12;
      startAt = "*-*-* 03:00:00";
      location = "/var/lib/minio/data/psql-backup";
      databases = config.services.postgresql.ensureDatabases;
    };

    # TODO - can i predefine 2fa?
    # TODO - can i integrate this with the backup service?
    pgadmin = {
      enable = true;
      initialEmail = "admin@racci.dev";
      initialPasswordFile = config.sops.secrets."PGADMIN_PASSWORD".path;
      settings = {
        DEFAULT_BINARY_PATHS = {
          pg-16 = "${pkgs.postgresql_16}/bin";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ config.services.couchdb.port ];
}
