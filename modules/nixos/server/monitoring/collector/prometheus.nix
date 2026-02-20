{
  serverConfigurations,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    ;

  cfg = config.server.monitoring;

  # Build scrape targets from all server configurations
  nodeTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.node.enable)
    |> builtins.map (c: "${c.host.name}:9100");

  caddyTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.caddy.enable)
    |> builtins.map (c: "${c.host.name}:2019");

  postgresTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.postgres.enable)
    |> builtins.map (c: "${c.host.name}:9187");

  redisTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.redis.enable)
    |> builtins.map (c: "${c.host.name}:9121");
in
{
  config = mkIf (cfg.enable && cfg.collector.enable) {
    services.prometheus = {
      enable = true;
      port = 9090;
      listenAddress = "0.0.0.0";

      retentionTime = cfg.retention.metrics;

      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            { targets = nodeTargets; }
          ];
        }
      ]
      ++ (lib.optional (caddyTargets != [ ]) {
        job_name = "caddy";
        static_configs = [
          { targets = caddyTargets; }
        ];
      })
      ++ (lib.optional (postgresTargets != [ ]) {
        job_name = "postgres";
        static_configs = [
          { targets = postgresTargets; }
        ];
      })
      ++ (lib.optional (redisTargets != [ ]) {
        job_name = "redis";
        static_configs = [
          { targets = redisTargets; }
        ];
      });
    };

    networking.firewall.allowedTCPPorts = [ 9090 ];
  };
}
