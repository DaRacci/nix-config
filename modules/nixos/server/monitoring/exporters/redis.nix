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
        sops.templates."redis-exporter-password".content = builtins.toJSON {
          "reids://localhost:16379" = config.sops.placeholder."REDIS/PASSWORD";
        };

        services.prometheus.exporters.redis = {
          enable = true;
          port = 9121;
          extraFlags = [
            "--redis.password-file %d/redis-password"
          ];
        };

        networking.firewall.allowedTCPPorts = [ 9121 ];

        systemd.services.prometheus-redis-exporter.serviceConfig.LoadCredential = [
          "redis-password:${config.sops.templates."redis-exporter-password".path}"
        ];
      };
}
