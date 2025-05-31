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
  };

  config = lib.mkIf (isNixio || (builtins.length (builtins.attrNames cfg.postgres)) > 0) {
    assertions =
      (
        if isNixio then
          [
            (
              let
                allDatabaseNames = lib.pipe serverConfigurations [
                  (builtins.map (cfg: builtins.attrNames cfg.server.database.postgres))
                  builtins.concatLists
                ];
                duplicateNames = lib.pipe allDatabaseNames [
                  (builtins.groupBy (pair: pair))
                  (lib.filterAttrs (_: names: (builtins.length names) > 1))
                  (lib.mapAttrsToList (name: _: name))
                ];
              in
              {
                assertion = builtins.length duplicateNames == 0;
                message = ''
                  Duplicate database names found: ${builtins.toString duplicateNames}
                '';
              }
            )
          ]
        else
          [ ]
      )
      ++ [
        {
          assertion = isNixio || !config.services.postgresql.enable;
          message = ''
            PostgreSQL is enabled but you have configured databases for management with NixIO.
            If this is on purpose and you want NixIO to manage these, set `services.postgresl.enable` to `false`.

            Configured databases: ${builtins.toString config.services.postgresql.ensureDatabases}
          '';
        }
      ];

    sops.secrets = lib.pipe cfg.postgres [
      builtins.attrValues
      (map (
        database:
        lib.nameValuePair "POSTGRES/${lib.toUpper database.database}_PASSWORD" (
          lib.optionalAttrs (database.password.owner != null) {
            inherit (database.password) owner;
          }
        )
        // (lib.optionalAttrs (database.password.group != null) {
          inherit (database.password) group;
        })
      ))
      lib.listToAttrs
    ];

    services.postgresql = lib.mkIf isNixio rec {
      ensureDatabases = lib.pipe serverConfigurations [
        (builtins.map (cfg: builtins.attrNames cfg.server.database.postgres))
        lib.flatten
      ];

      ensureUsers = builtins.map (database: {
        name = database;
        ensureDBOwnership = true;
      }) ensureDatabases;

      # Some modules configure initialScripts for postgres so we should ensure they are executed
      initialScript = lib.mkIf isNixio (
        lib.pipe (gatherAllInstances "services.postgresql.initialScript") [
          (builtins.map (path: builtins.readFile path))
          (builtins.concatStringsSep "\n")
          (pkgs.writeText "init-postgresql-script")
        ]
      );

      settings = {
        shared_preload_libraries =
          lib.pipe (gatherAllInstances "services.postgresql.settings.shared_preload_libraries")
            [
              (builtins.map (preload: if lib.isString preload then [ preload ] else preload))
              builtins.concatLists
              lib.unique
            ];
      };

      extensions =
        ps:
        lib.pipe serverConfigurations [
          (builtins.filter (cfg: cfg.host.name != "nixio"))
          (builtins.map (cfg: cfg.services.postgresql.extensions ps))
          builtins.concatLists
          lib.unique
        ];
    };

    systemd.services.postgresql =
      {
        # Sometimes this can get enabled on accident even if `services.postgresql.enable` is false.
        # This is due to some modules making changes to the service without any conditions for if postgres is local or not.
        enable = isNixio || config.services.postgresql.enable;
      }
      // (lib.optionalAttrs isNixio {
        postStart = lib.mkAfter (
          builtins.concatStringsSep "\n" (
            (lib.pipe (gatherAllInstances "systemd.services.postgresql.postStart") [
              # This skips the default postgresql start script https://github.com/NixOS/nixpkgs/blob/5b35d248e9206c1f3baf8de6a7683fee126364aa/nixos/modules/services/databases/postgresql.nix#L626-L640
              (builtins.map (
                script:
                let
                  # Assuming port 5432 as its the default.
                  startLine = ''PSQL="psql --port=5432"'';
                  endLine = "fi";
                  lines = lib.strings.splitString "\n" script;
                  startIndex = lib.lists.findFirstIndex (str: startLine == str) 0 lines;
                  endIndex = lib.lists.findFirstIndex (str: endLine == str) 0 lines;
                in
                lib.pipe lines [
                  (lib.drop startIndex)
                  (lib.take (builtins.length lines - (startIndex - endIndex)))
                  (builtins.concatStringsSep "\n")
                ]
              ))
              (builtins.filter (script: script != ""))
            ])
            ++ (lib.pipe serverConfigurations [
              (builtins.map (cfg: builtins.attrValues cfg.server.database.postgres))
              builtins.concatLists
              (builtins.map (database: lib.mine.mkPostgresRolePass database.user database.password.path))
            ])
          )
        );

        serviceConfig.ExecStartPost =
          lib.pipe (gatherAllInstances "systemd.services.postgresql.serviceConfig.ExecStartPost")
            [
              builtins.concatLists
              # We don't want to run the post-start scripts from each server.
              (builtins.filter (script: !lib.hasSuffix "postgresql-post-start" script))
            ];
      });
  };
}
