{
  isThisIOPrimaryHost,
  collectAllAttrs,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;

  hasRedisInstances =
    (collectAllAttrs "server.database.redis" |> builtins.attrNames |> builtins.length) > 0;
in
{
  config =
    mkIf (cfg.enable && cfg.exporters.redis.enable && isThisIOPrimaryHost && hasRedisInstances)
      {
        services.prometheus.exporters.redis = {
          enable = true;
          port = 9121;
          extraFlags = [
            "--redis.password-file ${config.sops.templates."REDIS/PASSWORD".path}"
          ];
        };

        networking.firewall.allowedTCPPorts = [ 9121 ];
      };
}
