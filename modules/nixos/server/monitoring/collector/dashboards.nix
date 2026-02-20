_:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;

  # Dashboard JSON files will be placed in the Nix store and provisioned by Grafana
  dashboardsDir = pkgs.runCommand "grafana-dashboards" { } ''
    mkdir -p $out
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: dashboard: "cp ${pkgs.writeText "${name}.json" (builtins.toJSON dashboard)} $out/${name}.json"
      ) dashboards
    )}
  '';

  dashboards = {
    cluster-overview = {
      annotations.list = [ ];
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      links = [ ];
      panels = [
        {
          title = "Hosts Up";
          type = "stat";
          datasource.type = "prometheus";
          targets = [
            {
              expr = "count(up{job=\"node\"} == 1)";
              legendFormat = "Up";
            }
          ];
          gridPos = {
            x = 0;
            y = 0;
            w = 4;
            h = 4;
          };
        }
        {
          title = "Hosts Down";
          type = "stat";
          datasource.type = "prometheus";
          targets = [
            {
              expr = "count(up{job=\"node\"} == 0) or vector(0)";
              legendFormat = "Down";
            }
          ];
          gridPos = {
            x = 4;
            y = 0;
            w = 4;
            h = 4;
          };
        }
        {
          title = "Active Alerts";
          type = "stat";
          datasource.type = "prometheus";
          targets = [
            {
              expr = "count(ALERTS{alertstate=\"firing\"}) or vector(0)";
              legendFormat = "Firing";
            }
          ];
          gridPos = {
            x = 8;
            y = 0;
            w = 4;
            h = 4;
          };
        }
        {
          title = "CPU Usage per Host";
          type = "timeseries";
          datasource.type = "prometheus";
          targets = [
            {
              expr = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)";
              legendFormat = "{{ instance }}";
            }
          ];
          gridPos = {
            x = 0;
            y = 4;
            w = 12;
            h = 8;
          };
        }
        {
          title = "Memory Usage per Host";
          type = "timeseries";
          datasource.type = "prometheus";
          targets = [
            {
              expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
              legendFormat = "{{ instance }}";
            }
          ];
          gridPos = {
            x = 12;
            y = 4;
            w = 12;
            h = 8;
          };
        }
        {
          title = "Disk Usage per Host";
          type = "timeseries";
          datasource.type = "prometheus";
          targets = [
            {
              expr = "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100";
              legendFormat = "{{ instance }}";
            }
          ];
          gridPos = {
            x = 0;
            y = 12;
            w = 12;
            h = 8;
          };
        }
        {
          title = "Network Traffic per Host";
          type = "timeseries";
          datasource.type = "prometheus";
          targets = [
            {
              expr = "rate(node_network_receive_bytes_total{device!~\"lo|veth.*|br.*\"}[5m]) * 8";
              legendFormat = "{{ instance }} rx";
            }
            {
              expr = "rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|br.*\"}[5m]) * 8";
              legendFormat = "{{ instance }} tx";
            }
          ];
          gridPos = {
            x = 12;
            y = 12;
            w = 12;
            h = 8;
          };
        }
      ];
      schemaVersion = 39;
      tags = [
        "cluster"
        "overview"
      ];
      templating.list = [ ];
      time = {
        from = "now-6h";
        to = "now";
      };
      title = "Cluster Overview";
      uid = "cluster-overview";
    };

    logs-explorer = {
      annotations.list = [ ];
      editable = true;
      panels = [
        {
          title = "Log Volume";
          type = "timeseries";
          datasource.type = "loki";
          targets = [
            {
              expr = "sum(count_over_time({job=~\".+\"}[5m])) by (host)";
              legendFormat = "{{ host }}";
            }
          ];
          gridPos = {
            x = 0;
            y = 0;
            w = 24;
            h = 6;
          };
        }
        {
          title = "Logs";
          type = "logs";
          datasource.type = "loki";
          targets = [
            {
              expr = "{job=~\".+\"}";
            }
          ];
          gridPos = {
            x = 0;
            y = 6;
            w = 24;
            h = 18;
          };
        }
      ];
      schemaVersion = 39;
      tags = [ "logs" ];
      templating.list = [ ];
      time = {
        from = "now-1h";
        to = "now";
      };
      title = "Logs Explorer";
      uid = "logs-explorer";
    };
  };
in
{
  config = mkIf (cfg.enable && cfg.collector.enable) {
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "default";
        orgId = 1;
        folder = "";
        type = "file";
        disableDeletion = false;
        editable = true;
        options.path = dashboardsDir;
      }
    ];
  };
}
