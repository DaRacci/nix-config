{
  isNixio,
  getNixioConfig,
  gatherAllInstances,
  gatherOtherInstances,
  serverConfigurations,

  ...
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    mkIf
    mkMerge
    ;
  inherit (types)
    str
    int
    attrsOf
    submodule
    nullOr
    ;
  cfg = config.server.database.postgres;

  postgresPort = getNixioConfig "services.postgresql.settings.port";
  allDatabaseNames = lib.pipe serverConfigurations [
    (builtins.map (cfg: builtins.attrNames cfg.server.database.postgres))
    builtins.concatLists
  ];

  hasPostgresDatabases = builtins.length (builtins.attrNames cfg) > 0;
  anyConfiguredPostgresAnywhere =
    builtins.length (
      gatherAllInstances "server.database.postgres"
      |> builtins.map builtins.attrNames
      |> builtins.concatLists
    ) > 0;
in
{
  options.server.database.postgres = mkOption {
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
              default = config.server.database.host;
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

  config = mkMerge [
    (mkIf (isNixio && anyConfiguredPostgresAnywhere) {
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
          gatherOtherInstances "services.postgresql.initialScript"
          |> builtins.map (path: builtins.readFile path)
          |> builtins.concatStringsSep "\n"
          |> pkgs.writeText "init-postgresql-script";

        settings = {
          shared_preload_libraries =
            gatherOtherInstances "services.postgresql.settings.shared_preload_libraries"
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
            (gatherOtherInstances "systemd.services.postgresql-setup.postStart")
            ++ (lib.pipe serverConfigurations [
              (builtins.map (cfg: builtins.attrValues cfg.server.database.postgres))
              builtins.concatLists
              (builtins.map (database: lib.mine.mkPostgresRolePass database.user database.password.path))
            ])
          )
        );

        serviceConfig.ExecStartPost =
          gatherOtherInstances "systemd.services.postgresql-setup.serviceConfig.ExecStartPost"
          |> builtins.concatLists;
      };
    })

    (mkIf (isNixio || hasPostgresDatabases) {
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

    (mkIf (!isNixio && hasPostgresDatabases) {
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
  ];
}
