{
  getIOPrimaryHostAttr,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf toUpper;

  cfg = config.server.monitoring;
  domain = getIOPrimaryHostAttr "server.proxy.domain";
in
{
  config = mkIf (cfg.enable && cfg.collector.enable && cfg.collector.tempo.enable) {
    services.tempo = {
      enable = true;

      settings = {
        target = "all";

        server.http_listen_port = 3200;

        distributor.receivers = {
          otlp = {
            protocols.http.endpoint = "127.0.0.1:${toString cfg.collector.tempo.otlpPort}";
          };
        };

        ingester = {
          lifecycler = {
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
          };
        };

        storage.trace = {
          backend = "s3";
          s3 = {
            endpoint = "minio.${domain}:9000";
            bucket = "tempo";
            insecure = false;
          };
          wal.path = "/var/lib/tempo/wal";
        };

        compactor = { };

        querier = { };

        metrics_generator = {
          registry.external_labels.source = "tempo";
          storage.path = "/var/lib/tempo/generated";
        };
      };
    };

    sops = {
      templates.tempoEnvironment = {
        content = lib.toShellVars {
          AWS_ACCESS_KEY_ID = config.sops.placeholder."${cfg.collector.tempo.minioAccessKeySecret}";
          AWS_SECRET_ACCESS_KEY = config.sops.placeholder."${cfg.collector.tempo.minioSecretKeySecret}";
        };
        restartUnits = [ "tempo.service" ];
      };

      secrets."${cfg.collector.tempo.minioAccessKeySecret}" = { };
      secrets."${cfg.collector.tempo.minioSecretKeySecret}" = { };
    };

    systemd.services.tempo.serviceConfig.EnvironmentFile =
      config.sops.templates.tempoEnvironment.path;

    server.dashboard.items.tempo = {
      title = "Tempo";
      url = "http://127.0.0.1:3200";
      icon = "mdi-timeline-clock";
    };
  };
}
