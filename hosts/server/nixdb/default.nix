{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  fromAllServers =
    pipe:
    lib.trivial.pipe self.nixosConfigurations (
      [
        # Exclude the current host
        (lib.filterAttrs (name: _: name != config.system.name))
        # Extract the config from each host
        builtins.attrValues
        (map (host: host.config))
        # Filter to only servers
        (builtins.filter (config: config.host.device.role == "server"))
      ]
      ++ pipe
    );
in
{
  services.metrics = {
    upgradeStatus.enable = false;
    hacompanion.enable = false;
  };

  server = {
    database.postgres.postgres = { };
    dashboard.items.pgadmin.title = "pgAdmin";

    proxy.virtualHosts.pgadmin.extraConfig = ''
      reverse_proxy http://localhost:${toString config.services.pgadmin.port}
    '';
  };

  services = {
    postgresql = {
      enable = true;
      package = pkgs.postgresql_17;
      enableJIT = true;
      enableTCPIP = true;

      extensions = ps: with ps; [ system_stats ];

      authentication = ''
        # TYPE  DATABASE  USER  ADDRESS   AUTH-METHOD   [AUTH-OPTIONS]
        local   all       all             peer
        local   all       all             trust
        local   all       all             scram-sha-256
      ''
      + (lib.pipe config.server.network.subnets [
        (map (
          subnet:
          [ "host  all  all  ${subnet.ipv4.cidr}  scram-sha-256" ]
          ++ lib.optionals (subnet.ipv6.cidr != null) [ "host  all  all  ${subnet.ipv6.cidr}  scram-sha-256" ]
        ))
        lib.flatten
        (builtins.concatStringsSep "\n")
      ]);

      settings = {
        password_encryption = "scram-sha-256";
        search_path = "\"$user\", public, vectors";
      };
    };

    postgresqlBackup = {
      enable = true;
      compression = "zstd";
      compressionLevel = 12;
      startAt = "*-*-* 03:00:00";
      location = "/var/lib/postgresql/backup";
      databases = config.services.postgresql.ensureDatabases;
    };

    pgadmin = {
      enable = true;
      initialEmail = "admin@racci.dev";
      initialPasswordFile = config.sops.secrets."PGADMIN_PASSWORD".path;
      settings = {
        DEFAULT_BINARY_PATHS = {
          pg-17 = "${pkgs.postgresql_17}/bin";
        };
      };
    };
  };

  sops.secrets = {
    PGADMIN_PASSWORD = {
      owner = config.users.users.pgadmin.name;
      group = config.users.groups.pgadmin.name;
      mode = "0400";
      restartUnits = [ "pgadmin.service" ];
    };

    "POSTGRES/POSTGRES_PASSWORD" = {
      owner = config.users.users.postgres.name;
      group = config.users.groups.postgres.name;
      mode = "0400";
      restartUnits = [ "postgresql.service" ];
    };
  }
  // fromAllServers [
    (map (config: config.sops.secrets))
    lib.mergeAttrsList
    (lib.filterAttrs (
      _name: secret:
      lib.strings.hasPrefix "POSTGRES/" secret.name && lib.strings.hasSuffix "_PASSWORD" secret.name
    ))
    (builtins.mapAttrs (
      _: value:
      (removeAttrs value [ "sopsFileHash" ])
      // {
        # Keep each secret's original sopsFile (its source host's own secrets.yaml)
        # rather than forcing all into one file. The shared hosts/server/secrets.yaml
        # does not yet contain the remote POSTGRES/*_PASSWORD keys.
        # TODO: Once all POSTGRES/*_PASSWORD are migrated to the shared file, restore
        # the `sopsFile = config.sops.defaultSopsFile;` override here.
        owner = config.users.users.postgres.name;
        group = config.users.groups.postgres.name;
        mode = "0400";
        restartUnits = [ "postgresql.service" ];
      }
    ))
  ];

  networking.firewall.allowedTCPPorts = [
    config.services.postgresql.settings.port
  ];
}
