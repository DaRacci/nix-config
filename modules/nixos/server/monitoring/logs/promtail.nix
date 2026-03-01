_:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;
  lokiHost = config.server.monitoringPrimaryHost;
in
{
  config = mkIf (cfg.enable && cfg.logs.enable) {
    services.promtail = {
      enable = true;

      configuration = {
        server = {
          http_listen_port = 9080;
          http_listen_address = "127.0.0.1";
          grpc_listen_port = 0;
        };

        clients = lib.optional (lokiHost != null) {
          url = "http://${lokiHost}:3100/loki/api/v1/push";
        };

        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.host.name;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
              {
                source_labels = [ "__journal__transport" ];
                target_label = "transport";
              }
              {
                source_labels = [ "__journal_priority_keyword" ];
                target_label = "priority";
              }
            ];
          }
        ];
      };
    };

  };
}
