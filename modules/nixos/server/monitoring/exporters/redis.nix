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
          "redis://localhost:16379" = config.sops.placeholder."REDIS/PASSWORD";
        };

        services.prometheus.exporters.redis = {
          enable = true;
          extraFlags = [
            "--redis.password-file %d/redis-password"
          ];
        };

        server.network.openPortsForSubnet.tcp = [ config.services.prometheus.exporters.redis.port ];

        systemd.services.prometheus-redis-exporter.serviceConfig.LoadCredential = [
          "redis-password:${config.sops.templates."redis-exporter-password".path}"
        ];
      };
}
