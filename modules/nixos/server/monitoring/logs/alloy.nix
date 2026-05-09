_:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    ;
  inherit (types) lines;

  cfg = config.server.monitoring;
  lokiHost = config.server.monitoringPrimaryHost;
  otlpCfg = cfg.collector.otlp;
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

  config = mkIf (cfg.enable && cfg.logs.enable) (mkMerge [
    {
      services.alloy = {
        enable = true;
        extraFlags = [
          "--disable-reporting"
          "--server.http.listen-addr=127.0.0.1:12345"
        ];
      };

      environment.etc."alloy/config.alloy".text =
        let
          # reusable regex pieces for alloy config (escaped for Nix -> alloy literal)
          regex = {
            # common tokens
            ws = ''\\s+''; # one or more whitespace
            ws_opt = ''\\s*''; # zero or more whitespace
            token = ''\\S+''; # single non-space token
            token_space = ''(?:\\S+\\s+)''; # token + trailing space
            token_space_opt = ''(?:\\S+\\s+)?''; # optional single token + space
            tokens_up_to_4 = ''(?:\\S+\\s+){0,4}''; # up to four leading tokens

            # small reusable prefixes
            ts_prefix = "(?:(?:ts|timestamp)=)?";

            # timestamp patterns
            syslog = ''[A-Z][a-z]{2}\\s+\\d{1,2}\\s+\\d{2}:\\d{2}:\\d{2}''; # May 09 10:35:28
            iso = ''\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}:\\d{2}(?:[.,]\\d+)?''; # 2026-05-09T10:33:12.916...
            apache = ''\\d{2}/[A-Za-z]{3}/\\d{4}:\\d{2}:\\d{2}:\\d{2}\\s[+\\-]\\d{4}''; # 09/May/2026:18:59:42 +1000
            unix = ''\\d{10}(?:\\.\\d{1,9})?''; # 1778325424 or 1778325424.123
            time_only = ''\\d{2}:\\d{2}:\\d{2}'';

            # log level patterns
            level_word = "(?:FATAL|CRITICAL|ERROR|WARN|WARNING|INFO|DEBUG|TRACE)";
            level_short = "(?:ERR|INF|WRN)";

            level_any = "(?:(?:FATAL|CRITICAL|ERROR|WARN|WARNING|INFO|DEBUG|TRACE)|(?:ERR|INF|WRN))";

            level_kv_key = "(?:level|lvl|severity)";
            level_sep = ''(?::|\\s+)'';

          };
        in
        ''
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
              stage.replace {
                # early slot: optional single token,
                expression = "^${regex.ws_opt}${regex.token_space_opt}${regex.ts_prefix}(?:(?P<prefix_ts>(?:${regex.syslog}|${regex.iso}|${regex.apache}|${regex.unix}))(?:(?::${regex.ws_opt})|(?:${regex.ws}))|(?:(?:(?:${regex.level_kv_key})=)?(?P<detected_level>${regex.level_any})${regex.level_sep}))(?P<message>.*)$"
                template   = "{{ .message }}"
              }

              stage.labels {
                values = {
                  detected_level = "detected_level",
                }
              }
            }

            stage.match {
              selector = "{transport=\"stdout\"}"
              stage.replace {
                # Bracketed early slot: up to 4 tokens then bracket containing timestamp or level.
                # Eats extra bracket tokens like [INF] [23], then colon/whitespace, then message.
                expression = "^${regex.ws_opt}${regex.tokens_up_to_4}\\[(?:(?P<bracket_ts>${regex.apache}|${regex.iso}|${regex.time_only})|(?P<detected_level>${regex.level_any}))\\](?:\\s*\\[[^\\]]*\\])*\\s*(?:[^:]+:\\s+|\\s+)(?P<message>.*)$"
                template   = "{{ .message }}"
              }

              stage.labels {
                values = {
                  detected_level = "detected_level",
                }
              }
            }

            stage.match {
              selector = "{transport=\"stdout\"}"
              stage.replace {
                # Numeric slot: optional token then unix epoch with colon/space, or level forms.
                expression = "^${regex.ws_opt}${regex.token_space_opt}(?:(?P<prefix_unix>${regex.unix}):${regex.ws_opt}|(?:(?:${regex.level_kv_key})=(?P<detected_level>${regex.level_any})\\b${regex.level_sep})|(?:(?P<detected_level>${regex.level_any})${regex.level_sep}))(?P<message>.*)$"
                template   = "{{ .message }}"
              }

              stage.labels {
                values = {
                  detected_level = "detected_level",
                }
              }
            }

            stage.labels {
              values = {
                detected_level = "detected_level",
              }
            }

            stage.template {
              source   = "detected_level"
              template = "{{ if .detected_level }}{{ ToLower .detected_level }}{{ else }}info{{ end }}"
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
              host = "${config.host.name}",
            }
          }

          ${config.server.monitoring.logs.extraConfiguration}
        '';

    }

    (mkIf (cfg.collector.enable && otlpCfg.enable) {
      sops.templates.monitoringAlloyEnvironment = {
        content = lib.toShellVars {
          OTLP_BEARER_TOKEN = config.sops.placeholder."${otlpCfg.bearerTokenSecret}";
        };
        restartUnits = [ "alloy.service" ];
      };

      services.alloy.environmentFile = config.sops.templates.monitoringAlloyEnvironment.path;
    })
  ]);
}
