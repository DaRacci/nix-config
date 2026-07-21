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
    optionals
    concatMap
    ;

  cfg = config.server.monitoring;
  otlpCfg = cfg.collector.otlp;

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

  processTargets =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.exporters.process.enable)
    |> map (c: "${c.host.name}:9256");

  # Collect declarative scrape configs from all servers (postgres pattern).
  # Each host declares server.monitoring.scrapeConfigs.<name> = { port = X; ... };
  # The collector aggregates them and creates sops.secrets for any bearer tokens.
  allScrapeConfigs =
    serverConfigurations
    |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.scrapeConfigs != { });

  hostScrapeConfigs =
    allScrapeConfigs
    |> concatMap (
      c:
      builtins.attrValues c.server.monitoring.scrapeConfigs
      |> map (
        sc:
        {
          inherit (sc) job_name metrics_path scheme;
          static_configs = [
            {
              targets = [ "${sc.host}:${toString sc.port}" ];
            }
          ];
        }
        // lib.optionalAttrs (sc.bearer_token_secret != null) {
          bearer_token_file = config.sops.secrets.${sc.bearer_token_secret}.path;
        }
      )
    );
in
{
  config = mkIf (cfg.enable && cfg.collector.enable) {
    users.users.prometheus.uid = mkForce 950;
    users.groups.prometheus.gid = mkForce 950;

    sops.secrets =
      allScrapeConfigs
      |> concatMap (
        c:
        builtins.attrValues c.server.monitoring.scrapeConfigs
        |> builtins.filter (sc: sc.bearer_token_secret != null)
        |> map (sc: {
          name = sc.bearer_token_secret;
          value = {
            owner = "prometheus";
            group = "prometheus";
          };
        })
      )
      |> builtins.listToAttrs;

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
      checkConfig = "syntax-only";
      port = 9090;
      listenAddress = "0.0.0.0";
      extraFlags = optionals otlpCfg.enable [ "--web.enable-remote-write-receiver" ];

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
        })
        ++ (optional (processTargets != [ ]) {
          job_name = "process";
          static_configs = [
            { targets = processTargets; }
          ];
        })
        ++ hostScrapeConfigs;
    };
  };
}
