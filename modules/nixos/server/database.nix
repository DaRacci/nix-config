{
  isNixio,
  getNixioConfig,
  ...
}:
{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.server.database;

  postgresHost = if isNixio then "localhost" else "nixio";
  postgresPort = getNixioConfig "services.postgresql.settings.port";

  serverConfigurations = lib.trivial.pipe self.nixosConfigurations [
    builtins.attrValues
    (builtins.map (host: host.config))
    (builtins.filter (cfg: cfg.host.device.role == "server"))
    (builtins.filter (cfg: cfg.server.database ? postgres && cfg.server.database.postgres != { }))
  ];

  gatherAllInstances =
    attrPath:
    lib.pipe serverConfigurations [
      (builtins.filter (cfg: cfg.host.name != "nixio"))
      (builtins.map (cfg: lib.attrsets.attrByPath (lib.splitString "." attrPath) null cfg))
      (builtins.filter (
        item:
        if lib.isList item then
          item != [ ]
        else if lib.isAttrs item then
          item != { }
        else
          item != null
      ))
    ];

  allDatabaseNames = lib.pipe serverConfigurations [
    (builtins.map (cfg: builtins.attrNames cfg.server.database.postgres))
    builtins.concatLists
  ];
  hasPostgresDatabases = builtins.length (builtins.attrNames cfg.postgres) > 0;
  hasRedisInstances = builtins.length (builtins.attrNames cfg.redis) > 0;
in
{
  options.server.database = with types; {
    postgres = mkOption {
      default = { };
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              database = mkOption {
                type = str;
                default = name;
                readOnly = true;
              };

              host = mkOption {
                type = str;
                default = postgresHost;
                readOnly = true;
              };

              port = mkOption {
                type = int;
                default = postgresPort;
                readOnly = true;
              };

              user = mkOption {
                type = str;
                default = name;
                readOnly = true;
              };

              password = mkOption {
                default = { };
                type = submodule {
                  options = {
                    path = mkOption {
                      type = types.path;
                      default =
                        config.sops.secrets."POSTGRES/${
                          lib.toUpper config.server.database.postgres.${name}.database
                          |> builtins.replaceStrings [ "-" ] [ "_" ]
                        }_PASSWORD".path;
                      readOnly = true;
                    };

                    owner = mkOption {
                      type = nullOr str;
                      default = null;
                    };

                    group = mkOption {
                      type = nullOr str;
                      default = null;
                    };
                  };
                };
              };
            };
          }
        )
      );
    };
    redis = mkOption {
      default = { };
      type = attrsOf (
        submodule (
          { ... }:
          {
            options = {
              host = mkOption {
                type = str;
                default = "localhost";
                readOnly = true;
              };

              port = mkOption {
                type = int;
                default = 6379;
                readOnly = true;
              };

              password = mkOption {
                type = nullOr str;
                default = null;
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (isNixio && hasPostgresDatabases) {
      assertions = [
        (
          let
            duplicateDatabaseNames =
              allDatabaseNames
              |> builtins.groupBy (v: v)
              |> lib.filterAttrs (_: names: (builtins.length names) > 1)
              |> builtins.attrNames;
          in
          {
            assertion = builtins.length duplicateDatabaseNames == 0;
            message = "Duplicate database names found: ${builtins.toString duplicateDatabaseNames}";
          }
        )
      ];

      services.postgresql = rec {
        ensureDatabases =
          serverConfigurations
          |> builtins.map (cfg: builtins.attrNames cfg.server.database.postgres)
          |> lib.flatten;

        ensureUsers = builtins.map (database: {
          name = database;
          ensureDBOwnership = true;
        }) ensureDatabases;

        # Some modules configure initialScripts for postgres so we should ensure they are executed
        initialScript =
          gatherAllInstances "services.postgresql.initialScript"
          |> builtins.map (path: builtins.readFile path)
          |> builtins.concatStringsSep "\n"
          |> pkgs.writeText "init-postgresql-script";

        settings = {
          shared_preload_libraries =
            gatherAllInstances "services.postgresql.settings.shared_preload_libraries"
            |> builtins.map (preload: if lib.isString preload then [ preload ] else preload)
            |> builtins.concatLists
            |> lib.unique;
        };

        extensions =
          ps:
          serverConfigurations
          |> builtins.filter (cfg: cfg.host.name != "nixio")
          |> builtins.map (cfg: cfg.services.postgresql.extensions ps)
          |> builtins.concatLists
          |> lib.unique;
      };

      systemd.services.postgresql-setup = {
        postStart = lib.mkAfter (
          builtins.concatStringsSep "\n" (
            (gatherAllInstances "systemd.services.postgresql-setup.postStart")
            ++ (lib.pipe serverConfigurations [
              (builtins.map (cfg: builtins.attrValues cfg.server.database.postgres))
              builtins.concatLists
              (builtins.map (database: lib.mine.mkPostgresRolePass database.user database.password.path))
            ])
          )
        );

        serviceConfig.ExecStartPost =
          gatherAllInstances "systemd.services.postgresql-setup.serviceConfig.ExecStartPost"
          |> builtins.concatLists;
      };
    })

    (lib.mkIf (isNixio || hasPostgresDatabases) {
      sops.secrets =
        builtins.attrValues cfg.postgres
        |> map (
          db:
          lib.nameValuePair
            "POSTGRES/${lib.toUpper db.database |> builtins.replaceStrings [ "-" ] [ "_" ]}_PASSWORD"
            {
              owner = lib.mkIf (db.password.owner != null) db.password.owner;
              group = lib.mkIf (db.password.group != null) db.password.group;
            }
        )
        |> lib.listToAttrs;
    })

    (lib.mkIf (!isNixio && hasPostgresDatabases) {
      assertions = [
        {
          assertion = !config.services.postgresql.enable;
          message = ''
            PostgreSQL is enabled & has databases configured, but you have configured databases for management with NixIO.
            If this is on purpose and you want NixIO to manage these, set `services.postgresl.enable` to `false`.

            Configured databases: ${builtins.toString config.services.postgresql.ensureDatabases}
          '';
        }
      ];

      services.postgresql.package = lib.mkDefault pkgs.postgresql_17;
    })

    (lib.mkIf (isNixio && hasRedisInstances) {
      services.redis.servers = {

      };
    })

    (lib.mkIf (!isNixio && hasRedisInstances) {
      assertions = [
        {
          assertion = !config.services.redis.enable;
          message = ''
            Redis is enabled & has instances, but you have configured databases for management with NixIO.
            If this is on purpose and you want NixIO to manage these, set `services.redis.enable` to `false`.

            Configured redis instances: ${
              builtins.attrNames config.services.redis.servers |> builtins.concatStringsSep ", "
            }
          '';
        }
      ];
    })
  ];
}
