{
  inputs,
  config,
  pkgs,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib)
    types
    optional
    mkIf
    mkMerge
    mkOption
    mkEnableOption
    toShellVars
    concatStringsSep
    ;
  inherit (types) str nullOr listOf;

  cfg = config.services.ai-agent;
in
{
  imports = optional importExternals inputs.hermes-agent.nixosModules.default;

  options.services.ai-agent = {
    enable = mkEnableOption "autonomous AI Agent service";

    dashboard = {
      enable = mkEnableOption "Hermes web dashboard";
    };

    memory = {
      enable = mkEnableOption "long-term memory using hermes-lcm";
    };

    apiServer = {
      enable = mkEnableOption "the OpenAI comptable endpoint";
      tokenReference = mkOption {
        type = str;
        default = "AI_AGENT/API_SERVER_TOKEN";
        description = "The sops secret attribute for the API server authentication token.";
      };
      port = mkOption {
        type = str;
        default = "8642";
        description = "The port for the API server to listen on.";
      };
      host = mkOption {
        type = str;
        default = "127.0.0.1";
        description = "The host/IP for the API server to bind to.";
      };
    };

    voice = {
      enable = mkEnableOption "voice input and output using the TTS and STT";
    };

    platform = {
      discord = {
        enable = mkEnableOption "Discord as a messaging channel";
        tokenReference = mkOption {
          type = str;
          default = "AI_AGENT/DISCORD_BOT_TOKEN";
          description = "The sops secret attribute for the Discord bot token.";
        };
        homeChannel = mkOption {
          type = nullOr str;
          description = "The Discord channel ID to use as the home channel for the agent.";
        };
        allowedUsers = mkOption {
          type = listOf str;
          default = [ ];
          description = "A list of Discord user IDs that the agent is allowed to interact with.";
        };
      };

      hassio = {
        enable = mkEnableOption "Home Assistant as a tool and notification channel";
        tokenReference = mkOption {
          type = str;
          default = "AI_AGENT/HASSIO_TOKEN";
          description = "The sops secret attribute for the Home Assistant long-lived access token.";
        };
        url = mkOption {
          type = str;
          description = "The URL for the Home Assistant instance, including the scheme.";
        };
      };
    };

    models = {
      primary = mkOption {
        type = str;
        default = "deepseek/deepseek-v4-flash";
        description = "The primary language model to use for the AI agent.";
      };

      vision = mkOption {
        type = str;
        default = "google/gemini-3-flash-preview";
        description = "The vision model to delegate image understanding tasks to.";
      };

      compression = mkOption {
        type = str;
        default = "deepseek/deepseek-v4-flash";
        description = ''
          The model to use for compression of context, summorisation and similar tasks that don't require reasoning.
          This model still needs a decently sized context window to be effective.
        '';
      };

      simpleton = mkOption {
        type = str;
        default = "stepfun/step-3.5-flash";
        description = "The simpleton model to delegate tasks to that require less reasoning, basic understanding and small context windows.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.hermes-agent = {
        enable = true;
        container.enable = true;

        settings = {
          model = {
            base_url = "https://openrouter.ai/api/v1";
            default = cfg.models.primary;
          };

          toolsets = [ "all" ];
          cron.wrap_response = true;
          checkpoints.enabled = true;
          code_execution.mode = "project";

          agent = {
            max_turns = 150;
            gateway_timeout = 1800;
            restart_drain_timeout = 180;
            api_max_retries = 3;
            tool_use_enforcement = "auto";
            gateway_timeout_warning = 900;
            gateway_notify_interval = 180;
            gateway_auto_continue_freshness = 3600;
            image_input_mode = "auto";
          };

          auxiliary = {
            approval.model = cfg.models.simpleton;
            compression.model = cfg.models.compression;
            curator.model = cfg.models;
            session_search.model = cfg.models.simpleton;
            title_generation.model = cfg.models.compression;
          };

          terminal = {
            backend = "local";
            container_persistent = true;
            persistent_shell = true;
          };

          compression = {
            enabled = true;
            engine = "lcm";
          };

          browser = {
            record_sessions = true;
            engine = "auto";
            dialog_policy = "must_respond";
            dialog_timeout_s = 300;
          };

          web = {
            search_backend = "searxng";
            extract_backend = "firecrawl";
          };

          display = {
            resume_display = "full";
            busy_input_mode = "steer";
            tui_auto_resume_recent = true;
            bell_on_complete = true;
            show_reasoning = true;
            streaming = true;
            final_response_markdown = "strip";
            persistent_output = true;
            inline_diffs = true;
            show_cost = true;
            skin = "mono";
            language = "en";
            tool_progress = "all";
          };

          streaming = {
            enabled = true;
            transport = "edit";
          };

          memory = {
            memory_enabled = true;
            user_profile_enabled = true;
          };

          privacy.redact_pii = true;

          security = {
            redact_secrets = true;
            tirith_enabled = true;
            tirith_path = "tirith";
            tirith_timeout = 5;
            tirith_fail_open = true;
          };

          approvals = {
            mode = "smart";
            timeout = 60;
            cron_mode = "deny";
            mcp_reload_confirm = true;
          };

          discord = {
            auto_thread = true;
          };
        };
      };

      systemd.services.hermes-dashboard = mkIf cfg.dashboard.enable {
        description = "Hermes web dashboard";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "simple";
          User = "hermes";
          Group = "hermes";
          WorkingDirectory = "/var/lib/hermes";
          ExecStart = "${config.services.hermes-agent.package}/bin/hermes dashboard --host 0.0.0.0 --no-open --insecure";
          Restart = "on-failure";
          RestartSec = 5;
          SupplementaryGroups = [ "docker" ];
        };
      };

      networking.firewall.allowedTCPPorts = [ 9119 ];
    })

    (mkIf (cfg.enable && cfg.memory.enable) {
      services.hermes-agent = {
        extraPlugins = [
          (pkgs.fetchFromGitHub {
            owner = "stephenschoettler";
            repo = "hermes-lcm";
            rev = "v0.9.2";
            hash = "sha256-0z83j4Mhv1n66fKYSVuEkBAGHXwOBmxQG/4CtyfIwrE=";
          })
        ];

        environment = {
          LCM_SUMMARY_MODEL = cfg.models.compression;
          LCM_EXPANSION_MODEL = cfg.models.compression;
          LCM_LARGE_OUTPUT_EXTERNALIZATION_ENABLED = "true";
          LCM_IGNORE_MESSAGE_PATTERNS = "^Cronjob Response:,^>>>Cronjob Response<<<:";
        };

        settings.plugins.enabled = [ "hermes-lcm" ];
      };
    })

    (mkIf (cfg.enable && cfg.apiServer.enable) {
      sops = {
        secrets."${cfg.apiServer.tokenReference}" = { };
        templates."HERMES_API_ENV".content = lib.toShellVars {
          API_SERVER_ENABLED = "true";
          API_SERVER_HOST = cfg.apiServer.host;
          API_SERVER_PORT = cfg.apiServer.port;
          API_SERVER_KEY = config.sops.placeholder."${cfg.apiServer.tokenReference}";
        };
      };

      services.hermes-agent.environmentFiles = [ config.sops.templates."HERMES_API_ENV".path ];
    })

    (mkIf (cfg.enable && cfg.voice.enable) {
      services.hermes-agent.settings = {
        voice = {
          auto_tts = true;
        };

        stt = {
          provider = "local";
          local.model = "large-v3";
        };

        tts = {
          provider = "neutts";
          neutts = {
            ref_audio = "";
            ref_text = "";
            model = "neuphonic/neutts-air-q4-gguf";
            device = "gpu";
          };
        };
      };
    })

    (mkIf (cfg.enable && cfg.platform.discord.enable) {
      sops = {
        secrets."${cfg.platform.discord.tokenReference}" = { };
        templates."HERMES_DISCORD_ENV".content = toShellVars {
          DISCORD_BOT_TOKEN = config.sops.placeholder."${cfg.platform.discord.tokenReference}";
          DISCORD_ALLOWED_USERS = concatStringsSep " " cfg.platform.discord.allowedUsers;
          DISCORD_HOME_CHANNEL = cfg.platform.discord.homeChannel;
        };
      };

      services.hermes-agent = {
        environmentFiles = [ config.sops.templates."HERMES_DISCORD_ENV".path ];
        settings.discord = {
          auto_thread = true;
          require_mention = true;
        };
      };
    })

    (mkIf (cfg.enable && cfg.platform.hassio.enable) {
      assertions = [
        {
          assertion = cfg.platform.hassio.tokenReference != null;
          message = "Home Assistant token reference must be specified when Home Assistant platform is enabled.";
        }
        {
          assertion = cfg.platform.hassio.url != null;
          message = "Home Assistant URL must be specified when Home Assistant platform is enabled.";
        }
      ];

      sops.templates."HERMES_HASSIO_ENV".content = toShellVars {
        HASS_TOKEN = config.sops.placeholder."AI_AGENT/HASSIO_TOKEN";
        HASS_URL = cfg.platform.hassio.url;
      };
    })
  ];
}
