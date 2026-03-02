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
    mkForce
    mkIf
    optional
    ;

  cfg = config.server.monitoring;

  # Build scrape targets from all server configurations
  nodeTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.node.enable)
    |> map (c: "${c.host.name}:9100");

  caddyTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.caddy.enable)
    |> map (c: "${c.host.name}:3019");

  postgresTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.postgres.enable)
    |> map (c: "${c.host.name}:9187");

  redisTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.redis.enable)
    |> map (c: "${c.host.name}:9121");
in
{
  config = mkIf (cfg.enable && cfg.collector.enable) {
    users.users.prometheus.uid = mkForce 950;
    users.groups.prometheus.gid = mkForce 950;

    server.storage.bucketMounts.prometheus = {
      mountLocation = "/var/lib/prometheus2";
      uid = 950;
      gid = 950;
      umask = 077;
    };

    server.proxy.virtualHosts.prometheus =
      let
        inherit (config.services.prometheus) port listenAddress;
      in
      {
        ports = [ port ];
        extraConfig = ''
          reverse_proxy http://${listenAddress}:${toString port}
        '';
      };

    services.prometheus = {
      enable = true;
      port = 9090;
      listenAddress = "0.0.0.0";

      retentionTime = cfg.retention.metrics;

      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };

      scrapeConfigs =
        (optional (nodeTargets != [ ]) {
          job_name = "node";
          static_configs = [
            { targets = nodeTargets; }
          ];
        })
        ++ (optional (caddyTargets != [ ]) {
          job_name = "caddy";
          static_configs = [
            { targets = caddyTargets; }
          ];
        })
        ++ (optional (postgresTargets != [ ]) {
          job_name = "postgres";
          static_configs = [
            { targets = postgresTargets; }
          ];
        })
        ++ (optional (redisTargets != [ ]) {
          job_name = "redis";
          static_configs = [
            { targets = redisTargets; }
          ];
        });
    };
  };
}
