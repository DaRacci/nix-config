{ fromAllServers, ... }:
{
  config,
  pkgs,
  lib,
  self,
  ...
}:
let
  inherit (lib)
    mergeAttrsList
    mapAttrs
    filterAttrs
    concatStringsSep
    optionalString
    optional
    unique
    listToAttrs
    nameValuePair
    strings
    ;
  inherit (strings) hasPrefix hasSuffix;
  inherit (builtins) attrNames attrValues concatMap;

  clusterPostgresDatabases =
    fromAllServers [
      (map (hostConfig: {
        ${hostConfig.system.name} = hostConfig.server.database.postgres;
      }))
      mergeAttrsList
    ]
    // {
      ${config.system.name} = config.server.database.postgres;
    };

  declaringHosts = attrNames (filterAttrs (_: databases: databases != { }) clusterPostgresDatabases);

  databasePorts = [
    config.services.postgresql.settings.port
    config.services.couchdb.port
  ];

  postgresSources =
    host:
    [ "${self.data.network.cluster.hosts.${host}}/128" ]
    ++ optional (host == config.system.name) "127.0.0.1/32"
    ++ optional (host == config.system.name) "::1/128";

  postgresRule = address: db: "host  ${db.database}  ${db.user}  ${address}  scram-sha-256";

  clusterPostgresRules = unique (
    concatMap (
      host:
      concatMap (address: map (postgresRule address) (attrValues clusterPostgresDatabases.${host})) (
        postgresSources host
      )
    ) declaringHosts
  );
in
{
  # For backups to be placed in the minio data directory.
  users.users.postgres.extraGroups = [ "minio" ];

  sops.secrets = {
    # COUCHDB_SETTINGS = {
    #   owner = config.users.users.couchdb.name;
    #   group = config.users.groups.couchdb.name;
    #   restartUnits = [ "couchdb.service" ];
    # };

    PGADMIN_PASSWORD = {
      owner = config.users.users.pgadmin.name;
      group = config.users.groups.pgadmin.name;
      restartUnits = [ "pgadmin.service" ];
    };

    "POSTGRES/POSTGRES_PASSWORD" = {
      owner = config.users.users.postgres.name;
      group = config.users.groups.postgres.name;
      restartUnits = [ "postgresql.service" ];
      mode = "0440";
    };
  }
  // fromAllServers [
    (map (config: config.sops.secrets))
    mergeAttrsList
    (filterAttrs (
      _name: secret: hasPrefix "POSTGRES/" secret.name && hasSuffix "_PASSWORD" secret.name
    ))
    (mapAttrs (
      _: value:
      (removeAttrs value [ "sopsFileHash" ])
      // {
        sopsFile = config.sops.defaultSopsFile;
        # Update owner and groups because it will always be only postgres on this server.
        owner = config.users.users.postgres.name;
        group = config.users.groups.postgres.name;
        # TODO - do i need to clean up the reload services?
        restartUnits = [ "postgresql.service" ];
      }
    ))
  ];

  server = {
    database.postgres.postgres = { };
    dashboard.items.pgadmin.title = "pgAdmin";

    proxy.virtualHosts.pgadmin.extraConfig = ''
      reverse_proxy http://localhost:${toString config.services.pgadmin.port}
    '';
  };

  services = {
    couchdb = {
      enable = false;
      package = pkgs.couchdb3;
      bindAddress = "::";
      extraConfigFiles = [
        config.sops.secrets."COUCHDB_SETTINGS".path
      ];
    };

    postgresql = {
      enable = true;
      package = pkgs.postgresql_17;
      enableJIT = true;
      enableTCPIP = true;

      extensions =
        ps:
        let
          inherit (ps) system_stats;
        in
        [ system_stats ];

      authentication = ''
        # TYPE  DATABASE  USER  ADDRESS   AUTH-METHOD   [AUTH-OPTIONS]
        local   all       all             peer
        local   all       all             trust
        local   all       all             scram-sha-256
      ''
      + optionalString (clusterPostgresRules != [ ]) (
        "\n" + concatStringsSep "\n" clusterPostgresRules + "\n"
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
      initialEmail = self.data.site.adminEmail;
      initialPasswordFile = config.sops.secrets."PGADMIN_PASSWORD".path;
      settings = {
        DEFAULT_BINARY_PATHS = {
          pg-16 = "${pkgs.postgresql_16}/bin";
        };
      };
    };
  };

  server.network.openPortsForSources = listToAttrs (
    map (host: nameValuePair host { tcp = databasePorts; }) declaringHosts
  );
}
