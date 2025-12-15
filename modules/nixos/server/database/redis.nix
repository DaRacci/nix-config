{
  isNixio,
  getNixioConfig,
  gatherAllInstances,
  ...
}:
{
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkMerge
    mkIf
    types
    ;
  inherit (types)
    attrsOf
    submodule
    str
    int
    ;

  file = "${self}/hosts/server/nixio/redis-mappings.json";
  staticDbIdMappings =
    (if builtins.pathExists file then builtins.readFile file else "{}") |> builtins.fromJSON;

  cfg = config.server.database.redis;
  redisPort =
    (getNixioConfig "services.redis.servers")
    |> lib.filterAttrs (n: _: n == "")
    |> builtins.mapAttrs (_: s: s.port)
    |> builtins.attrValues
    |> builtins.head;
  hasRedisInstances = builtins.length (builtins.attrNames cfg) > 0;
  allRedisInstances = gatherAllInstances "server.database.redis";
  allRedisPrefixNames = allRedisInstances |> lib.mergeAttrsList |> builtins.attrNames;
  anyConfiguredRedisAnywhere =
    (allRedisInstances |> builtins.map builtins.attrNames |> builtins.concatLists |> builtins.length)
    > 0;
in
{
  options.server.database.redis = mkOption {
    default = { };
    type = attrsOf (
      submodule (
        { name, ... }:
        {
          options = {
            prefix = mkOption {
              type = str;
              default = name;
              readOnly = true;
            };

            database_id = mkOption {
              type = int;
              default = staticDbIdMappings.${name} or (-1);
              readOnly = true;
            };

            host = mkOption {
              type = str;
              default = config.server.database.host;
              readOnly = true;
            };

            port = mkOption {
              type = int;
              default = redisPort;
              readOnly = true;
            };
          };
        }
      )
    );
  };

  config = mkMerge [
    (mkIf (isNixio && anyConfiguredRedisAnywhere) {
      assertions = [
        {
          assertion = builtins.length allRedisPrefixNames <= 16;
          message = ''
            You have configured ${toString (builtins.length allRedisPrefixNames)} Redis instances,
            but Redis only supports 16 databases (0-15). Please reduce the number of configured
            Redis instances to at most 16.

            Configured redis instances: ${builtins.concatStringsSep ", " allRedisPrefixNames}
          '';
        }
        {
          assertion =
            (builtins.attrNames staticDbIdMappings |> builtins.length)
            == (builtins.attrValues staticDbIdMappings |> lib.unique |> builtins.length);
          message = ''
            You have configured duplicate static database_id mappings for Redis instances.
            Each Redis client must have a unique database_id mapping to avoid conflicts.

            Configured static mappings: ${
              builtins.attrNames staticDbIdMappings
              |> builtins.map (name: "${name} -> ${toString staticDbIdMappings.${name}}")
              |> builtins.concatStringsSep ", "
            }
          '';
        }
      ];

      sops.secrets."REDIS/PASSWORD" =
        let
          cfg = config.services.redis.servers."";
        in
        {
          owner = cfg.user;
          inherit (cfg) group;
        };

      services.redis.servers."" = {
        enable = true;
        openFirewall = true;
        bind = null;
        requirePassFile = config.sops.secrets."REDIS/PASSWORD".path;
      };
    })

    (mkIf (!isNixio && hasRedisInstances) {
      assertions = [
        {
          assertion = !(config.services.redis.servers ? "" && config.services.redis.servers."".enable);
          message = ''
            Redis is enabled & has instances, but you have configured databases for management with NixIO.
            If this is on purpose and you want NixIO to manage these, set `services.redis.enable` to `false`.

            Configured redis instances: ${
              builtins.attrNames config.services.redis.servers |> builtins.concatStringsSep ", "
            }
          '';
        }
      ]
      ++ (
        builtins.attrNames cfg
        |> builtins.map (name: {
          assertion = staticDbIdMappings ? ${name};
          message = ''
            Redis instance "${name}" does not have a static database_id mapping configured in
            hosts/server/nixio/reddis-mappings.json.

            Run `update-redis-mappings` to automatically generate and insert the required mappings.

            Configured static mappings: ${
              staticDbIdMappings
              |> lib.mapAttrsToList (prefix: id: "${prefix} -> ${toString id}")
              |> builtins.concatStringsSep ", "
            }
          '';
        })
      );
    })
  ];
}
