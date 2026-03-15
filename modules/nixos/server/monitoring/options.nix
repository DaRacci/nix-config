{
  isThisIOPrimaryHost,
  isThisMonitoringPrimaryHost,
  collectAllAttrs,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkOption
    ;
  inherit (lib.types)
    str
    ;

  hasPostgresDatabases =
    (collectAllAttrs "server.database.postgres" |> builtins.attrNames |> builtins.length) > 0;
  hasRedisInstances =
    (collectAllAttrs "server.database.redis" |> builtins.attrNames |> builtins.length) > 0;

  cfg = config.server.monitoring;
in
{
  options.server.monitoring = {
    enable = mkEnableOption "monitoring for this server" // {
      default = true;
    };

    retention = {
      metrics = mkOption {
        type = str;
        default = "90d";
        description = "Prometheus TSDB retention period.";
      };

      logs = mkOption {
        type = str;
        default = "90d";
        description = "Loki log retention period.";
      };
    };

    exporters = {
      node = {
        enable = mkEnableOption "node_exporter for system-level metrics" // {
          default = cfg.enable;
        };
      };

      caddy = {
        enable = mkEnableOption "Caddy metrics exporter" // {
          default = cfg.enable && config.services.caddy.enable;
          defaultText = literalExpression "cfg.enable && config.services.caddy.enable";
        };
      };

      postgres = {
        enable = mkEnableOption "PostgreSQL exporter" // {
          default = cfg.enable && isThisIOPrimaryHost && hasPostgresDatabases;
          defaultText = literalExpression "cfg.enable && thisIsIOPrimaryHost && hasPostgresDatabases";
        };
      };

      redis = {
        enable = mkEnableOption "Redis exporter" // {
          default = cfg.enable && isThisIOPrimaryHost && hasRedisInstances;
          defaultText = literalExpression "cfg.enable && thisIsIOPrimaryHost && hasRedisInstances";
        };
      };
    };

    logs = {
      enable = mkEnableOption "Promtail log shipping" // {
        default = cfg.enable;
      };
    };

    collector = {
      enable = mkEnableOption "monitoring collector services (Prometheus, Loki, Grafana)" // {
        default = isThisMonitoringPrimaryHost && cfg.enable;
        defaultText = literalExpression "thisIsMonitoringPrimaryHost && cfg.enable";
      };

      grafana = {
        kanidm = {
          enable = mkEnableOption "Kanidm OAuth2 authentication for Grafana" // {
            default = true;
          };
        };
      };

      alerting = {
        enable = mkEnableOption "Alertmanager and alert rules" // {
          default = true;
        };

        homeAssistant = {
          enable = mkEnableOption "Home Assistant webhook alerting" // {
            default = false;
          };
        };

        nextcloudTalk = {
          enable = mkEnableOption "Nextcloud Talk webhook alerting" // {
            default = false;
          };
        };
      };

      proxmox = {
        enable = mkEnableOption "Proxmox VE metrics collection" // {
          default = true;
        };
      };
    };
  };
}
