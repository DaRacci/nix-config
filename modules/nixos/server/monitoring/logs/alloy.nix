_:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (types) lines;

  cfg = config.server.monitoring;
  lokiHost = config.server.monitoringPrimaryHost;
in
{
  options.server.monitoring.logs = {
    extraConfiguration = mkOption {
      type = lines;
      default = "";
      description = ''
        Additional configuration for the alloy log processor.
        This is useful for adding custom Loki stages, relabeling rules, or write targets.

        Note that the default configuration for processing the system journal is always included and does not need to be specified here.
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.logs.enable) {
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
          url = "http://${lokiHost}:3100/loki/api/v1/push"
        }
        external_labels = {}
      }

      loki.process "journal" {
        forward_to = [loki.relabel.journal.receiver]

        stage.match {
          selector = "{transport=\"stdout\"}"
          stage.regex {
            expression = "^(?P<legacy_timestamp>\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}) (?P<message>.*)$"
          }

          stage.template {
            source   = "detected_level"
            template = "info"
          }

          stage.labels {
            values = {
              detected_level = "detected_level"
            }
          }

          stage.timestamp {
            source = "legacy_timestamp"
            format = "2006/01/02 15:04:05"
          }
        }

        stage.match {
          selector = "{transport=\"stdout\"}"
          stage.regex {
            expression = "^(?P<iso_timestamp>\\d{4}-\\d{2}-\\d{2}T[^ ]+)\\s+(?P<level>INFO|WARN|WARNING|ERROR|ERR|DEBUG|TRACE|FATAL|CRITICAL)\\s+(?P<message>.*)$"
          }

          stage.template {
            source   = "detected_level"
            template = "{{ ToLower .level }}"
          }

          stage.labels {
            values = {
              detected_level = "detected_level"
            }
          }

          stage.timestamp {
            source = "iso_timestamp"
            format = "RFC3339Nano"
          }
        }

        stage.template {
          source   = "detected_level"
          template = "{{ if .detected_level }}{{ .detected_level }}{{ else }}info{{ end }}"
        }
      }

      loki.relabel "journal" {
        forward_to = [loki.write.default.receiver]

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        rule {
          source_labels = ["__journal__transport"]
          target_label  = "transport"
        }

        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "priority"
        }

        rule {
          source_labels = ["detected_level"]
          target_label  = "level"
        }
      }

      loki.source.journal "journal" {
        forward_to    = [loki.process.journal.receiver]
        max_age       = "12h"
        relabel_rules = loki.relabel.journal.rules

        labels = {
          host = "${config.host.name}"
        }
      }

      ${config.server.monitoring.logs.extraConfiguration}
    '';
  };
}
