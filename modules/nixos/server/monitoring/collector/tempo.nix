{
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
  config = mkIf (cfg.enable && cfg.collector.enable && cfg.collector.tempo.enable) {
    services.tempo = {
      enable = true;

      settings = {
        target = "all";

        server.http_listen_port = 3200;

        distributor.receivers = {
          otlp = {
            protocols.http.endpoint = "0.0.0.0:${toString cfg.collector.tempo.otlpPort}";
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
          backend = "local";
          local.path = "/var/lib/tempo/blocks";
          wal.path = "/var/lib/tempo/wal";
        };

        compactor = { };

        querier = { };

        metrics_generator = {
          storage.path = "/var/lib/tempo/generated";
          registry.external_labels.source = "tempo";
        };
      };
    };

    server.storage.swfsMount.tempo = {
      backend = "minio";
      mountLocation = "/var/lib/tempo";
      uid = config.users.users.tempo.uid;
      gid = config.users.groups.tempo.gid;
      umask = 007;
      requiredByServices = [ "tempo" ];
    };

    server.dashboard.items.tempo = {
      title = "Tempo";
      url = "http://127.0.0.1:3200";
      icon = "mdi-timeline-clock";
    };
  };
}
