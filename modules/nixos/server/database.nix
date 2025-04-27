{
  flake,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.server.database;

  isNixio = config.host.name == "nixio";
  nixioConfig = flake.nixosConfigurations.nixio.config;
  getNixioConfig =
    attrPath:
    let
      configuration = if isNixio then config else nixioConfig;
      attrs = lib.splitString "." attrPath;
    in
    lib.lists.foldl' (acc: attr: acc.${attr}) configuration attrs;

  postgresHost = if isNixio then "localhost" else "nixio";
  postgresPort = getNixioConfig "services.postgresql.settings.port";
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

  config = lib.mkIf ((builtins.length (builtins.attrNames cfg.postgres)) > 0) {
    sops.secrets = lib.pipe cfg.postgres [
      builtins.attrValues
      (map (
        database:
        lib.nameValuePair "POSTGRES/${lib.toUpper database.database}" (
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

    services.postgresql = {
      ensureDatabases = builtins.attrNames cfg.postgres;
      ensureUsers = lib.pipe cfg.postgres [
        builtins.attrValues
        (map (database: {
          name = database.user;
          ensureDBOwnership = true;
        }))
      ];
    };

    systemd.services.postgresql = {
      enable = lib.mkDefault isNixio;
      postStart = lib.pipe cfg.postgres [
        builtins.attrValues
        (map (database: lib.mine.mkPostgresRolePass database.user database.password.path))
        (lib.concatStringsSep "\n")
      ];
    };
  };
}
