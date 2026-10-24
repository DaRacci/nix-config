{
  serverConfigurations,
  ...
}:
{
  config,
  lib,
  pkgs,
  hostDirectory,
  ...
}:
let
  inherit (lib)
    concatMap
    escapeShellArgs
    getExe
    mkAfter
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    optionalString
    types
    ;
  inherit (types) lines;

  cfg = config.server.monitoring;
  lokiHost = config.server.monitoringPrimaryHost;
  otlpCfg = cfg.collector.otlp;

  rateLimitCfg = cfg.logs.rateLimit;
  captureCfg = cfg.logs.capture;
  relayCfg = captureCfg.relay;

  # Escape a regex for use inside an Alloy double-quoted string.
  alloyRegex = value: lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] value;

  dropUnitRegex = alloyRegex (lib.concatStringsSep "|" (map lib.escapeRegex cfg.logs.dropUnits));
  dropLevelRegex = alloyRegex (lib.concatStringsSep "|" (map lib.escapeRegex cfg.logs.dropLevels));
  limitLevelRegex = alloyRegex (lib.concatStringsSep "|" (map lib.escapeRegex rateLimitCfg.levels));

  captureEnvFile = "/run/alloy-dynamic-capture.env";
  neverMatchRegex = "__never_match__";

  openCapturePort = captureCfg.listenAddress != "127.0.0.1" && captureCfg.listenAddress != "::1";

  captureCtlExe = getExe pkgs.alloy-dynamic-capture-ctl;
  captureAPIExe = getExe pkgs.alloy-dynamic-capture-api;
  captureRelayExe = getExe pkgs.alloy-dynamic-capture-relay;

  alloySopsFile = name: {
    sopsFile = "${hostDirectory}/alloy/${name}";
    format = "binary";
  };

  captureAPIArgs = [
    "--listen-address"
    captureCfg.listenAddress
    "--port"
    (toString captureCfg.port)
    "--default-ttl"
    (toString captureCfg.defaultTTLSeconds)
    "--max-ttl"
    (toString captureCfg.maxTTLSeconds)
    "--ctl"
    captureCtlExe
    "--ctl-state-file"
    captureEnvFile
    "--ctl-never-match-regex"
    neverMatchRegex
    "--ctl-default-ttl"
    (toString captureCfg.defaultTTLSeconds)
    "--ctl-max-ttl"
    (toString captureCfg.maxTTLSeconds)
    "--ca-cert"
    config.sops.secrets."${captureCfg.tls.caCertSecret}".path
    "--server-cert"
    config.sops.secrets."${captureCfg.tls.serverCertSecret}".path
    "--server-key"
    config.sops.secrets."${captureCfg.tls.serverKeySecret}".path
  ]
  ++ concatMap (cn: [
    "--allowed-cn"
    cn
  ]) captureCfg.allowedClientCommonNames;

  captureAPIExecStart = "${captureAPIExe} ${escapeShellArgs captureAPIArgs}";

  captureRelayArgs = [
    "--listen-address"
    relayCfg.listenAddress
    "--port"
    (toString relayCfg.port)
    "--default-ttl"
    (toString relayCfg.defaultTTLSeconds)
    "--max-ttl"
    (toString relayCfg.maxTTLSeconds)
    "--dynamic-port"
    (toString captureCfg.port)
    "--dynamic-ca-cert"
    config.sops.secrets."${relayCfg.tls.caCertSecret}".path
    "--dynamic-client-cert"
    config.sops.secrets."${relayCfg.tls.clientCertSecret}".path
    "--dynamic-client-key"
    config.sops.secrets."${relayCfg.tls.clientKeySecret}".path
  ]
  ++ concatMap (target: [
    "--target"
    target
  ]) relayCfg.targets;

  captureRelayExecStart = "${captureRelayExe} ${escapeShellArgs captureRelayArgs}";

  commonListenerOpts = role: defaultAddr: defaultPort: {
    listenAddress = mkOption {
      type = types.str;
      default = defaultAddr;
      description = "Address for the ${role} listener.";
    };

    port = mkOption {
      type = types.port;
      default = defaultPort;
      description = "Port for the ${role} listener.";
    };

    defaultTTLSeconds = mkOption {
      type = types.ints.positive;
      default = 1800;
      description = "Default expanded-capture duration when no TTL is specified.";
    };

    maxTTLSeconds = mkOption {
      type = types.ints.positive;
      default = 14400;
      description = "Maximum allowed expanded-capture duration.";
    };
  };
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

    dropUnits = mkOption {
      type = types.listOf types.str;
      default = [
        "hermes-agent.service"
        "minio.service"
        "seaweedfs.service"
        "uptime-kuma.service"
        "hacompanion.service"
      ];
      description = ''
        Journal units whose log lines are dropped before shipping.
        Use this for high-volume units whose output is not useful in Loki.
      '';
    };

    dropLevels = mkOption {
      type = types.listOf types.str;
      default = [
        "debug"
        "trace"
      ];
      description = ''
        Detected log levels that are dropped before shipping.
      '';
    };

    rateLimit = {
      enable = mkEnableOption "rate-limiting low-value journal logs" // {
        default = true;
      };

      levels = mkOption {
        type = types.listOf types.str;
        default = [
          "info"
          "debug"
          "trace"
        ];
        description = ''
          Levels affected by the journal rate limit.
        '';
      };

      rate = mkOption {
        type = types.ints.positive;
        default = 120;
        description = "Maximum journal lines per second allowed for rate-limited levels.";
      };

      burst = mkOption {
        type = types.ints.positive;
        default = 600;
        description = "Burst size for the journal rate limiter.";
      };
    };

    capture = {
      enable = mkEnableOption "mTLS API to temporarily disable journal drops and limits";
    }
    // (commonListenerOpts "capture API" "0.0.0.0" 12445)
    // {
      allowedClientCommonNames = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Optional allow-list of client certificate common names.
          Empty means any client cert signed by the configured CA is accepted.
        '';
      };

      tls = {
        caCertSecret = mkOption {
          type = types.str;
          default = "MONITORING/ALLOY_DYNAMIC/CA_CERT";
          description = "SOPS secret containing the PEM CA trust bundle used to verify client certificates.";
        };

        serverCertSecret = mkOption {
          type = types.str;
          default = "MONITORING/ALLOY_DYNAMIC/SERVER_CERT";
          description = "SOPS secret containing the PEM server certificate chain (leaf followed by intermediate) for the capture API.";
        };

        serverKeySecret = mkOption {
          type = types.str;
          default = "MONITORING/ALLOY_DYNAMIC/SERVER_KEY";
          description = "SOPS secret containing the PEM server private key for the capture API.";
        };
      };

      relay = {
        enable = mkEnableOption "loopback relay so Grafana can manually trigger expanded capture" // {
          default = true;
        };
      }
      // (commonListenerOpts "relay" "127.0.0.1" 12446)
      // {
        targets = mkOption {
          type = types.listOf types.str;
          default =
            serverConfigurations
            |> builtins.filter (c: c.server.monitoring.enable && c.server.monitoring.logs.enable)
            |> map (c: c.host.name);
          description = "Hosts the relay is allowed to trigger for expanded capture.";
        };

        tls = {
          caCertSecret = mkOption {
            type = types.str;
            default = "MONITORING/ALLOY_DYNAMIC/CA_CERT";
            description = "SOPS secret containing the PEM CA trust bundle for upstream capture APIs.";
          };

          clientCertSecret = mkOption {
            type = types.str;
            default = "MONITORING/ALLOY_DYNAMIC/CLIENT_CERT";
            description = "SOPS secret containing the PEM client certificate chain (leaf followed by intermediate) used by the relay.";
          };

          clientKeySecret = mkOption {
            type = types.str;
            default = "MONITORING/ALLOY_DYNAMIC/CLIENT_KEY";
            description = "SOPS secret containing the PEM client private key used by the relay.";
          };
        };
      };
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

      systemd.services.alloy = {
        environment =
          (optionalAttrs (cfg.logs.dropUnits != [ ]) {
            ALLOY_DROP_UNITS_REGEX = dropUnitRegex;
          })
          // (optionalAttrs (cfg.logs.dropLevels != [ ]) {
            ALLOY_DROP_LEVELS_REGEX = dropLevelRegex;
          })
          // (optionalAttrs rateLimitCfg.enable {
            ALLOY_LIMIT_LEVELS_REGEX = limitLevelRegex;
          });

        serviceConfig.EnvironmentFile = mkAfter [ "-${captureEnvFile}" ];
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

            ${optionalString (cfg.logs.dropUnits != [ ]) ''
              stage.match {
                selector            = "{unit=~\"" + sys.env("ALLOY_DROP_UNITS_REGEX") + "\"}"
                action              = "drop"
                drop_counter_reason = "noisy_unit"
              }
            ''}

            stage.match {
              selector = "{transport=\"stdout\"}"
              stage.replace {
                expression = "^${regex.ws_opt}${regex.token_space_opt}${regex.ts_prefix}(?:(?P<prefix_ts>(?:${regex.syslog}|${regex.iso}|${regex.apache}|${regex.unix}))(?:(?::${regex.ws_opt})|(?:${regex.ws}))|(?:(?:(?:${regex.level_kv_key})=)?(?P<detected_level>${regex.level_any})${regex.level_sep}))(?P<message>.*)$"
                replace    = "{{ .message }}"
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
                expression = "^${regex.ws_opt}${regex.tokens_up_to_4}\\[(?:(?P<bracket_ts>${regex.apache}|${regex.iso}|${regex.time_only})|(?P<detected_level>${regex.level_any}))\\](?:\\s*\\[[^\\]]*\\])*\\s*(?:[^:]+:\\s+|\\s+)(?P<message>.*)$"
                replace    = "{{ .message }}"
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
                expression = "^${regex.ws_opt}${regex.token_space_opt}(?:(?P<prefix_unix>${regex.unix}):${regex.ws_opt}|(?:(?:${regex.level_kv_key})=(?P<detected_level>${regex.level_any})\\b${regex.level_sep})|(?:(?P<detected_level>${regex.level_any})${regex.level_sep}))(?P<message>.*)$"
                replace    = "{{ .message }}"
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

            ${optionalString (cfg.logs.dropLevels != [ ]) ''
              stage.match {
                selector            = "{detected_level=~\"" + sys.env("ALLOY_DROP_LEVELS_REGEX") + "\"}"
                action              = "drop"
                drop_counter_reason = "low_value_level"
              }
            ''}

            ${optionalString rateLimitCfg.enable ''
              stage.match {
                selector = "{detected_level=~\"" + sys.env("ALLOY_LIMIT_LEVELS_REGEX") + "\"}"

                stage.limit {
                  rate  = ${toString rateLimitCfg.rate}
                  burst = ${toString rateLimitCfg.burst}
                  drop  = true
                }
              }
            ''}
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
      sops = {
        secrets."${otlpCfg.bearerTokenSecret}" = { };
        templates.monitoringAlloyEnvironment = {
          content = lib.toShellVars {
            OTLP_BEARER_TOKEN = config.sops.placeholder."${otlpCfg.bearerTokenSecret}";
          };
          restartUnits = [ "alloy.service" ];
        };
      };

      services.alloy.environmentFile = config.sops.templates.monitoringAlloyEnvironment.path;
    })

    (mkIf captureCfg.enable {
      sops.secrets = {
        "${captureCfg.tls.caCertSecret}" = alloySopsFile "CA_CERT";
        "${captureCfg.tls.serverCertSecret}" = alloySopsFile "SERVER_CERT";
        "${captureCfg.tls.serverKeySecret}" = alloySopsFile "SERVER_KEY";
      };

      systemd.services.alloy-dynamic-capture = {
        description = "mTLS API for temporary Alloy expanded capture";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "alloy.service"
        ];

        serviceConfig = {
          Type = "simple";
          ExecStart = captureAPIExecStart;
          Restart = "always";
          RestartSec = 5;
          User = "root";
          Group = "root";
        };
      };

      server.network.openPortsForSubnet.tcp = lib.optional openCapturePort captureCfg.port;
    })

    (mkIf (cfg.collector.enable && captureCfg.enable && relayCfg.enable) {
      sops.secrets = {
        "${relayCfg.tls.caCertSecret}" = alloySopsFile "CA_CERT";
        "${relayCfg.tls.clientCertSecret}" = alloySopsFile "CLIENT_CERT";
        "${relayCfg.tls.clientKeySecret}" = alloySopsFile "CLIENT_KEY";
      };

      systemd.services.alloy-dynamic-capture-relay = {
        description = "Loopback relay for Grafana manual dynamic-capture triggers";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = captureRelayExecStart;
          Restart = "always";
          RestartSec = 5;
          User = "root";
          Group = "root";
        };
      };
    })
  ]);
}
