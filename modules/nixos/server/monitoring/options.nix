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
    attrsOf
    int
    nullOr
    str
    submodule
    enum
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
          defaultText = literalExpression "cfg.enable";
        };
      };

      process = {
        enable = mkEnableOption "Process exporter for monitoring specific processes" // {
          default = cfg.enable;
          defaultText = literalExpression "cfg.enable";
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

      fail2ban = {
        enable = mkEnableOption "fail2ban metrics exporter" // {
          default = cfg.enable && isThisIOPrimaryHost && config.server.fail2ban.enable or false;
          defaultText = literalExpression "cfg.enable && isThisIOPrimaryHost && config.server.fail2ban.enable";
        };
      };
    };

    scrapeConfigs = mkOption {
      default = { };
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              job_name = mkOption {
                type = str;
                default = name;
                description = "Prometheus job name for this scrape target.";
              };

              host = mkOption {
                type = str;
                default = config.host.name;
                defaultText = literalExpression "config.host.name";
                description = "Host to scrape metrics from.";
              };

              port = mkOption {
                type = int;
                description = "Port the metrics endpoint listens on.";
              };

              metrics_path = mkOption {
                type = str;
                default = "/metrics";
                description = "HTTP path to the metrics endpoint.";
              };

              scheme = mkOption {
                type = enum [ "http" "https" ];
                default = "http";
                description = "URL scheme for scraping.";
              };

              bearer_token_secret = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  SOPS secret path for bearer token authentication.
                  When set, the secret will be created on the monitoring primary host.
                '';
              };
            };
          }
        )
      );
      description = ''
        Declarative scrape configs for services running on this host.
        These are collected by the monitoring primary host and converted
        into Prometheus scrape configurations.
      '';
    };

    logs = {
      enable = mkEnableOption "Alloy log shipping" // {
        default = cfg.enable;
        defaultText = literalExpression "cfg.enable";
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

      otlp = {
        enable = mkEnableOption "OTLP/HTTP ingestion via Grafana Alloy" // {
          default = isThisMonitoringPrimaryHost && cfg.enable;
          defaultText = literalExpression "isThisMonitoringPrimaryHost && cfg.enable";
        };

        port = mkOption {
          type = int;
          default = 4318;
          description = "Port for the OTLP/HTTP ingestion endpoint.";
        };

        bearerTokenSecret = mkOption {
          type = str;
          default = "MONITORING/OLTP/BEARER_TOKEN";
          description = "SOPS secret path used as the bearer token for OTLP/HTTP ingestion.";
        };

        subdomain = mkOption {
          type = str;
          default = "otlp";
          description = "Subdomain used for the OTLP/HTTP ingestion endpoint.";
        };
      };

      alerting = {
        enable = mkEnableOption "Alertmanager and alert rules" // {
          default = cfg.enable;
          defaultText = literalExpression "cfg.enable";
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
          default = isThisMonitoringPrimaryHost && cfg.enable;
          defaultText = literalExpression "isThisMonitoringPrimaryHost && cfg.enable";
        };
      };
    };
  };
}
