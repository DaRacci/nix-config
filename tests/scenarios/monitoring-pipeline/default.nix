# Monitoring Pipeline Scenario — Node Definitions
# Two-node VM config: nixmon (monitoring primary, collector services) and nixio (target host, exporters).
{
  nodes = {
    nixmon = { pkgs, ... }: {
      # Prometheus collector
      services.prometheus = {
        enable = true;
        port = 9090;
        listenAddress = "0.0.0.0";
        retentionTime = "7d";
        globalConfig = {
          scrape_interval = "15s";
          evaluation_interval = "15s";
        };
        scrapeConfigs = [
          {
            job_name = "node";
            static_configs = [ { targets = [ "nixio:9100" ]; } ];
          }
          {
            job_name = "caddy";
            static_configs = [ { targets = [ "nixio:3019" ]; } ];
          }
          {
            job_name = "postgres";
            static_configs = [ { targets = [ "nixio:9187" ]; } ];
          }
        ];
        ruleFiles = [
          (pkgs.writeText "alert-rules.yml" (
            builtins.toJSON {
              groups = [
                {
                  name = "test-alerts";
                  rules = [
                    {
                      alert = "TestAlert";
                      expr = "vector(1)";
                      labels.severity = "warning";
                      annotations.summary = "Test alert rule loaded";
                    }
                  ];
                }
              ];
            }
          ))
        ];
      };

      # Loki log storage
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
            ring.kvstore.store = "inmemory";
          };
          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index.prefix = "index_";
              index.period = "24h";
            }
          ];
          storage_config.filesystem.directory = "/var/lib/loki/chunks";
          limits_config = {
            retention_period = "7d";
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
          };
        };
      };

      networking.firewall.allowedTCPPorts = [
        9090
        3100
      ];
    };

    nixio = _: {
      # Node exporter
      services.prometheus.exporters.node = {
        enable = true;
        port = 9100;
        listenAddress = "0.0.0.0";
      };

      # Postgres exporter
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        ensureDatabases = [ "testdb" ];
        ensureUsers = [ { name = "testuser"; } ];
      };
      services.prometheus.exporters.postgres = {
        enable = true;
      };

      # Caddy with metrics
      services.caddy = {
        enable = true;
        globalConfig = "metrics per_host";
        virtualHosts = {
          ":2015".extraConfig = "respond \"Caddy test endpoint\"";
          ":3019".extraConfig = "metrics";
        };
      };

      # Alloy log shipping to nixmon
      services.alloy = {
        enable = true;
        extraFlags = [
          "--disable-reporting"
          "--server.http.listen-addr=127.0.0.1:12345"
        ];
      };
      environment.etc."alloy/config.alloy".text = ''
        loki.write "default" {
          endpoint {
            url = "http://nixmon:3100/loki/api/v1/push"
          }
          external_labels = {}
        }

        loki.source.journal "journal" {
          forward_to    = [loki.write.default.receiver]
          max_age       = "12h"
          labels = {
            host = "nixio",
          }
        }
      '';

      networking.firewall.allowedTCPPorts = [
        9100
        3019
        9187
      ];
    };
  };
}
