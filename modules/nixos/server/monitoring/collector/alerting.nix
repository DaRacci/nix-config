_:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    ;

  cfg = config.server.monitoring;
  alertCfg = cfg.collector.alerting;

  alertRules = pkgs.writeText "prometheus-alert-rules.yml" (
    builtins.toJSON {
      groups = [
        {
          name = "node-alerts";
          rules = [
            {
              alert = "HostDown";
              expr = "up{job=\"node\"} == 0";
              "for" = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Host {{ $labels.instance }} is down";
                description = "{{ $labels.instance }} has been unreachable for more than 2 minutes.";
              };
            }
            {
              alert = "DiskSpaceCritical";
              expr = "(node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100 < 10";
              "for" = "5m";
              labels.severity = "critical";
              annotations = {
                summary = "Disk space critical on {{ $labels.instance }}";
                description = "Root filesystem on {{ $labels.instance }} has less than 10% space remaining.";
              };
            }
            {
              alert = "HighCPUUsage";
              expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 90";
              "for" = "5m";
              labels.severity = "warning";
              annotations = {
                summary = "High CPU usage on {{ $labels.instance }}";
                description = "CPU usage on {{ $labels.instance }} has exceeded 90% for more than 5 minutes.";
              };
            }
            {
              alert = "HighMemoryUsage";
              expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90";
              "for" = "5m";
              labels.severity = "warning";
              annotations = {
                summary = "High memory usage on {{ $labels.instance }}";
                description = "Memory usage on {{ $labels.instance }} has exceeded 90% for more than 5 minutes.";
              };
            }
          ];
        }
      ];
    }
  );
in
{
  config = mkIf (cfg.enable && cfg.collector.enable && alertCfg.enable) (mkMerge [
    {
      services.prometheus = {
        alertmanagers = [
          {
            static_configs = [
              { targets = [ "localhost:9093" ]; }
            ];
          }
        ];

        ruleFiles = [ alertRules ];
      };

      services.prometheus.alertmanager = {
        enable = true;
        port = 9093;
        listenAddress = "0.0.0.0";

        configuration = {
          global = {
            resolve_timeout = "5m";
          };

          route = {
            receiver = "default";
            group_by = [
              "alertname"
              "instance"
            ];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";

            routes =
              (lib.optional alertCfg.homeAssistant.enable {
                receiver = "home-assistant";
                matchers = [ ''severity=~"critical|warning"'' ];
                continue = true;
              })
              ++ (lib.optional alertCfg.nextcloudTalk.enable {
                receiver = "nextcloud-talk";
                matchers = [ ''severity="critical"'' ];
                continue = false;
              });
          };

          receivers = [
            { name = "default"; }
          ]
          ++ (lib.optional alertCfg.homeAssistant.enable {
            name = "home-assistant";
            webhook_configs = [
              {
                url_file = config.sops.secrets."MONITORING/HOME_ASSISTANT/WEBHOOK_URL".path;
                send_resolved = true;
              }
            ];
          })
          ++ (lib.optional alertCfg.nextcloudTalk.enable {
            name = "nextcloud-talk";
            webhook_configs = [
              {
                url_file = config.sops.secrets."MONITORING/NEXTCLOUD_TALK/WEBHOOK_URL".path;
                send_resolved = true;
              }
            ];
          });
        };
      };
    }

    (mkIf alertCfg.homeAssistant.enable {
      sops.secrets."MONITORING/HOME_ASSISTANT/WEBHOOK_URL" = { };
    })

    (mkIf alertCfg.nextcloudTalk.enable {
      sops.secrets."MONITORING/NEXTCLOUD_TALK/WEBHOOK_URL" = { };
    })
  ]);
}
