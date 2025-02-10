{ subnets, fromAllServers, ... }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  shouldCopyPostgres =
    config:
    (builtins.hasAttr "postgresql" config.systemd.services)
    && !config.systemd.services.postgresql.enable;
in
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

  services = {
    couchdb = {
      enable = true;
      package = pkgs.couchdb_3;
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

      extensions =
        ps:
        fromAllServers [
          (builtins.filter shouldCopyPostgres)
          (builtins.map (config: config.services.postgresql.extensions ps))
          builtins.concatLists
          lib.unique
        ];

      ensureDatabases = fromAllServers [
        (builtins.filter (
          config:
          (shouldCopyPostgres config) && (builtins.length config.services.postgresql.ensureDatabases) >= 1
        ))
        (builtins.map (config: config.services.postgresql.ensureDatabases))
        builtins.concatLists
        lib.unique
      ];

      ensureUsers = fromAllServers [
        (builtins.filter (
          config: (shouldCopyPostgres config) && (builtins.length config.services.postgresql.ensureUsers) >= 1
        ))
        (builtins.map (config: config.services.postgresql.ensureUsers))
        builtins.concatLists
        lib.unique
      ];

      initialScript = fromAllServers [
        (builtins.filter (
          config: (shouldCopyPostgres config) && config.services.postgresql.initialScript != null
        ))
        (builtins.map (config: config.services.postgresql.initialScript))
        (builtins.filter (path: path != null))
        (builtins.map (path: builtins.readFile path))
        (builtins.concatStringsSep "\n")
        (pkgs.writeText "init-sql-script")
      ];

      settings = {
        password_encryption = "scram-sha-256";

        shared_preload_libraries = fromAllServers [
          (builtins.filter (
            config:
            (shouldCopyPostgres config) && config.services.postgresql.settings.shared_preload_libraries != null
          ))
          (builtins.map (config: config.services.postgresql.settings.shared_preload_libraries))
          (builtins.map (preload: if lib.isString preload then [ preload ] else preload))
          builtins.concatLists
          lib.unique
        ];
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

  systemd.services.postgresql = {
    postStart =
      fromAllServers [
        (builtins.filter (
          config: (shouldCopyPostgres config) && config.systemd.services.postgresql.postStart != [ ]
        ))
        (builtins.map (config: config.systemd.services.postgresql.postStart))
        (builtins.concatStringsSep "\n")
      ]
      + (builtins.concatStringsSep "\n" [
        (lib.mine.mkPostgresRolePass "postgres" config.sops.secrets."POSTGRES/POSTGRES_PASSWORD".path)
      ]);

    serviceConfig.ExecStartPost = fromAllServers [
      (builtins.filter (
        config:
        (shouldCopyPostgres config) && config.systemd.services.postgresql.serviceConfig.ExecStartPost != [ ]
      ))
      (builtins.map (config: config.systemd.services.postgresql.serviceConfig.ExecStartPost))
      lib.flatten
      # We don't want to run the pre-start scripts from each server.
      (builtins.filter (script: !lib.hasSuffix "postgresql-post-start" script))
    ];
  };

  networking.firewall.allowedTCPPorts = [ config.services.couchdb.port ];
}
