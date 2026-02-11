{
  isThisIOPrimaryHost,
  getIOPrimaryHostAttr,
  collectAllAttrs,
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
    mapAttrsToList
    literalExpression
    ;
  inherit (types)
    attrsOf
    submodule
    str
    int
    ;

  cfg = config.server.database.redis;

  file = "${self}/hosts/server/${config.server.ioPrimaryHost}/redis-mappings.json";
  staticDbIdMappings =
    (if builtins.pathExists file then builtins.readFile file else "{}") |> builtins.fromJSON;

  redisPort = (getIOPrimaryHostAttr "services.redis.servers")."".port;
  hasRedisInstances = builtins.length (builtins.attrNames cfg) > 0;
  allRedisInstances = collectAllAttrs "server.database.redis";
  allRedisPrefixNames = allRedisInstances |> builtins.attrNames;
  anyConfiguredRedisAnywhere = (allRedisInstances |> builtins.attrNames |> builtins.length) > 0;
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
              defaultText = literalExpression ''
                staticDbIdMappings.${name} or (-1)
              '';
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
              default = redisPort;
              defaultText = literalExpression ''
                (getIOPrimaryHostAttr "services.redis.servers")."".port
              '';
              readOnly = true;
            };
          };
        }
      )
    );
  };

  config = mkMerge [
    (mkIf (isThisIOPrimaryHost && anyConfiguredRedisAnywhere) {
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

    (mkIf (!isThisIOPrimaryHost && hasRedisInstances) {
      assertions = [
        {
          assertion = !(config.services.redis.servers ? "" && config.services.redis.servers."".enable);
          message = ''
            Redis is enabled & has instances, but you have configured databases for management with an IO Host.
            If this is on purpose and you want IO Hosts to manage these, set `services.redis.enable` to `false`.

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
            hosts/server/${config.server.ioPrimaryHost}/reddis-mappings.json.

            Run `update-redis-mappings` to automatically generate and insert the required mappings.

            Configured static mappings: ${
              staticDbIdMappings
              |> mapAttrsToList (prefix: id: "${prefix} -> ${toString id}")
              |> builtins.concatStringsSep ", "
            }
          '';
        })
      );
    })
  ];
}
