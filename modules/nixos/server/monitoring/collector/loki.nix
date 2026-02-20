_:
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
  config = mkIf (cfg.enable && cfg.collector.enable) {
    server.proxy.virtualHosts.loki =
      let
        inherit (config.services.loki.configuration.server) http_listen_port http_listen_address;
      in
      {
        ports = [ http_listen_port ];
        extraConfig = ''
          reverse_proxy http://${http_listen_address}:${toString http_listen_port}
        '';
      };

    services.loki = {
      enable = true;

      configuration = {
        auth_enabled = false;

        server = {
          http_listen_port = 3100;
          http_listen_address = "0.0.0.0";
        };

        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;

          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        storage_config.filesystem.directory = "/var/lib/loki/chunks";

        limits_config = {
          retention_period = cfg.retention.logs;
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
          ingestion_rate_mb = 16;
          ingestion_burst_size_mb = 32;
        };

        compactor = {
          working_directory = "/var/lib/loki/compactor";
          compaction_interval = "10m";
          retention_enabled = true;
          retention_delete_delay = "2h";
          delete_request_store = "filesystem";
        };
      };
    };
  };
}
