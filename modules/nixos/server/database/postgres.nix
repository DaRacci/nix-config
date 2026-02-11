{
  isThisIOPrimaryHost,
  getIOPrimaryHostAttr,

  getOtherAttrs,
  collectAllAttrs,
  collectOtherAttrs,
  collectOtherAttrsFunc,
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
    filterAttrs
    isString
    listToAttrs
    mkAfter
    mkIf
    mkMerge
    mkOption
    nameValuePair
    toUpper
    types
    unique
    literalExpression
    ;
  inherit (types)
    attrsOf
    int
    nullOr
    path
    str
    submodule
    ;

  cfg = config.server.database.postgres;

  postgresPort = getIOPrimaryHostAttr "services.postgresql.settings.port";
  allDatabaseNames = collectAllAttrs "server.database.postgres" |> builtins.attrNames;

  hasPostgresDatabases = builtins.length (builtins.attrNames cfg) > 0;
  anyConfiguredPostgresAnywhere =
    (collectAllAttrs "server.database.postgres" |> builtins.attrNames |> builtins.length) > 0;
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
              defaultText = literalExpression ''
                config.server.database.host
              '';
              readOnly = true;
            };

            port = mkOption {
              type = int;
              default = postgresPort;
              defaultText = literalExpression ''
                config.server.database.postgres.${name}.port
              '';
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
                    type = path;
                    default =
                      config.sops.secrets."POSTGRES/${
                        toUpper config.server.database.postgres.${name}.database |> builtins.replaceStrings [ "-" ] [ "_" ]
                      }_PASSWORD".path;
                    defaultText = literalExpression ''
                      config.sops.secrets."POSTGRES/''${
                        toUpper config.server.database.postgres.''${name}.database |> builtins.replaceStrings [ "-" ] [ "_" ]
                      }_PASSWORD".path;
                    '';
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
    (mkIf (isThisIOPrimaryHost && anyConfiguredPostgresAnywhere) {
      assertions = [
        (
          let
            duplicateDatabaseNames =
              allDatabaseNames
              |> builtins.groupBy (v: v)
              |> filterAttrs (_: names: (builtins.length names) > 1)
              |> builtins.attrNames;
          in
          {
            assertion = builtins.length duplicateDatabaseNames == 0;
            message = "Duplicate database names found: ${toString duplicateDatabaseNames}";
          }
        )
      ];

      services.postgresql = rec {
        ensureDatabases = allDatabaseNames;

        ensureUsers = map (database: {
          name = database;
          ensureDBOwnership = true;
        }) ensureDatabases;

        # Some modules configure initialScripts for postgres so we should ensure they are executed
        initialScript =
          getOtherAttrs "services.postgresql.initialScript"
          |> map (path: builtins.readFile path)
          |> builtins.concatStringsSep "\n"
          |> pkgs.writeText "init-postgresql-script";

        settings = {
          shared_preload_libraries =
            collectOtherAttrsFunc "services.postgresql.settings.shared_preload_libraries" (
              preload: _: if isString preload then [ preload ] else preload
            )
            |> unique;
        };

        extensions =
          ps:
          getOtherAttrs "services.postgresql.extensions"
          |> map (ext: ext ps)
          |> builtins.concatLists
          |> unique;
      };

      systemd.services.postgresql-setup = {
        postStart = mkAfter (
          [
            (getOtherAttrs "systemd.services.postgresql-setup.postStart")
            (
              collectAllAttrs "server.database.postgres"
              |> builtins.attrValues
              |> builtins.map (database: lib.mine.mkPostgresRolePass database.user database.password.path)
            )
          ]
          |> builtins.concatLists
          |> builtins.concatStringsSep "\n"
        );

        serviceConfig.ExecStartPost = collectOtherAttrs "systemd.services.postgresql-setup.serviceConfig.ExecStartPost";
      };
    })

    (mkIf (isThisIOPrimaryHost || hasPostgresDatabases) {
      sops.secrets =
        builtins.attrValues cfg
        |> map (
          db:
          nameValuePair "POSTGRES/${toUpper db.database |> builtins.replaceStrings [ "-" ] [ "_" ]}_PASSWORD"
            {
              owner = mkIf (db.password.owner != null) db.password.owner;
              group = mkIf (db.password.group != null) db.password.group;
            }
        )
        |> listToAttrs;
    })

    (mkIf (!isThisIOPrimaryHost && hasPostgresDatabases) {
      assertions = [
        {
          assertion = !config.services.postgresql.enable;
          message = ''
            PostgreSQL is enabled & has databases configured, but you have configured databases for management with IO Hosts.
            If this is on purpose and you want IO Hosts to manage these, set `services.postgresl.enable` to `false`.

            Configured databases: ${builtins.toString config.services.postgresql.ensureDatabases}
          '';
        }
      ];

      services.postgresql.package = lib.mkDefault pkgs.postgresql_17;
    })
  ];
}
