{
  isThisIOPrimaryHost,
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
in
{
  config =
    mkIf
      (
        cfg.enable
        && cfg.exporters.redis.enable
        && isThisIOPrimaryHost
        && config.services.redis.servers."".enable
      )
      {
        services.prometheus.exporters.redis = {
          enable = true;
          port = 9121;
          extraFlags = [
            "--redis.password-file ${config.sops.secrets."REDIS/PASSWORD".path}"
          ];
        };

        networking.firewall.allowedTCPPorts = [ 9121 ];
      };
}
