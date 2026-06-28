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
  inherit (types)
    int
    str
    nullOr
    listOf
    addCheck
    ;

  cfg = config.services.ai-agent;
in
{
  imports = optional importExternals inputs.hermes-agent.nixosModules.default;

  options.services.ai-agent = {
    enable = mkEnableOption "autonomous AI Agent service";

    dashboard = {
      enable = mkEnableOption "Hermes web dashboard";

      port = mkOption {
        type = int;
        default = 9119;
        description = "The port for the dashboard to listen on.";
      };

      publicURL = mkOption {
        type = nullOr (addCheck str (url: builtins.match "https?://.+" url != null));
        description = ''
          The public URL for the dashboard, used for generating links in notifications and similar. If not set, localhost URLs will be used.

          If set, must be a valid URL starting with http:// or https://.
        '';
      };

      oidc = {
        enable = mkEnableOption "OpenID Connect authentication for the dashboard";

        provider = mkOption {
          type = str;
          default = "self-hosted";
          description = "The OIDC plugin to use for dashboard authentication.";
        };

        issuer = mkOption {
          type = str;
          description = "The OIDC issuer URL for dashboard authentication.";
        };

        clientId = mkOption {
          type = str;
          description = "The OIDC client ID for dashboard authentication.";
        };

        scopes = mkOption {
          type = listOf str;
          default = [
            "openid"
            "profile"
            "email"
          ];
          description = "The OIDC scopes to request for dashboard authentication.";
        };
      };
    };

    memory = {
      enable = mkEnableOption ''
        long-term memory

        When enabled this disables the builtin user profile and memory markdown features,
        to nudge the agent towards using the configured long-term memory provider for all memory.
      '';
    };

    apiServer = {
      enable = mkEnableOption "the OpenAI comptable endpoint";
      tokenReference = mkOption {
        type = str;
        default = "AI_AGENT/API_SERVER_TOKEN";
        description = "The sops secret attribute for the API server authentication token.";
      };
      port = mkOption {
        type = int;
        default = 8642;
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

      wyoming-stt = {
        enable = mkEnableOption "use existing Wyoming faster-whisper server for STT instead of running a separate Whisper instance";

        host = mkOption {
          type = str;
          default = "localhost";
          description = "The host of the Wyoming faster-whisper server.";
        };

        port = mkOption {
          type = int;
          default = 10300;
          description = "The port of the Wyoming faster-whisper server.";
        };
      };
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

      webhook = {
        port = mkOption {
          type = int;
          default = 8654;
          description = "The port for the webhook listener to listen on.";
        };
      };
    };

    models = {
      provider = mkOption {
        type = str;
        default = "openrouter";
        description = "The model provider to use.";
      };

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

          Used for auxilary models:
        '';
      };

      simpleton = mkOption {
        type = str;
        default = "stepfun/step-3.5-flash";
        description = ''
          The simpleton model to delegate tasks to that require less reasoning, basic understanding and small context windows.

          Used for auxilary models:
        '';
      };

      brains = mkOption {
        type = str;
        default = "deepseek/deepseek-v4-pro";
        description = ''
          The smartest model to use for complex reasoning and decision-making tasks.

          Used for auxilary models:
        '';
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.hermes-agent = {
        enable = true;
        container.enable = true;

        extraDependencyGroups = [
          "acp"
          "homeassistant"
          "messaging"
          "voice"
          "youtube"
        ];

        #TODO:Need a way to auto update these.
        extraPlugins = [
          (pkgs.fetchFromGitHub {
            owner = "FelineStateMachine";
            repo = "hermes-openspec";
            rev = "3cf148b1fcc8ee7ebaff307af88cc27869fc4cfd";
            sha256 = "sha256-5vLw5Y3Sz5DCwdc8mhUBOKWAF+i+dwAcL2sqWD96ANg=";
          })
        ];

        environment = {
          BASH_ENV = "/home/hermes/.bashrc";
          HOME = "/home/hermes"; # For some reason this is getting set to /var/lib/hermes inside the container
        };

        settings = {
          model = {
            base_url = "https://openrouter.ai/api/v1";
            default = cfg.models.primary;
          };

          toolsets = [ "all" ];
          checkpoints.enabled = true;
          code_execution.mode = "project";

          cron = {
            script_timeout_seconds = 600;
            wrap_response = true;
          };

          curator = {
            enabled = true;
            interval_hours = 24 * 7;
            min_idle_hours = 2;
            stale_after_days = 30;
            archive_after_days = 90;
            consolidate = true;
            prune_builtins = true;
          };

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
            approval = {
              inherit (cfg.models) provider;
              model = cfg.models.simpleton;
            };
            compression = {
              inherit (cfg.models) provider;
              model = cfg.models.compression;
            };
            curator = {
              inherit (cfg.models) provider;
              model = cfg.models.simpleton;
            };
            session_search = {
              inherit (cfg.models) provider;
              model = cfg.models.simpleton;
            };
            title_generation = {
              inherit (cfg.models) provider;
              model = cfg.models.compression;
            };
            triage_specifier = {
              inherit (cfg.models) provider;
              model = cfg.models.brains;
            };
            vision = {
              inherit (cfg.models) provider;
              model = cfg.models.vision;
            };
          };

          delegation = {
            max_concurrent_children = 24;
            max_spawn_depth = 3;
            model = cfg.models.primary;
            provider = "openrouter";
          };

          terminal = {
            backend = "local";
            container_persistent = true;
            persistent_shell = true;
          };

          compression = {
            enabled = true;
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

          platforms.webhook = {
            enabled = true;
            extra = {
              port = cfg.platform.webhook.port;
              rate_limit = 30;
            };
          };
        };
      };
    })

    (mkIf (cfg.enable && cfg.dashboard.enable) {
      services.hermes-agent.settings.dashboard = {
        public_url = cfg.dashboard.publicURL;
      };

      systemd.services.hermes-dashboard = {
        description = "Hermes web dashboard";
        after = [
          "network.target"
          "docker.service"
          "hermes-agent.service"
        ];
        requires = [ "docker.service" ];
        bindsTo = [ "hermes-agent.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "simple";
          User = "hermes";
          Group = "hermes";
          EnvironmentFile = config.services.hermes-agent.environmentFiles;
          PrivateTmp = true;
          ExecStart = "${lib.getExe pkgs.bash} -c 'env > /tmp/hermes-dashboard.env; exec docker exec -u hermes --env-file /tmp/hermes-dashboard.env hermes-agent /data/current-package/bin/hermes dashboard --host 0.0.0.0 --no-open --port ${toString cfg.dashboard.port}'";
          Restart = "on-failure";
          RestartSec = 5;
          SupplementaryGroups = [ "docker" ];
          ReadWritePaths = [ "/var/run/docker.sock" ];
        };
      };

      networking.firewall.allowedTCPPorts = [ cfg.dashboard.port ];
    })

    (mkIf (cfg.enable && cfg.memory.enable) {
      services.hermes-agent = {
        extraPythonPackages = [
          pkgs.mnemosyne-memory
          pkgs.mnemosyne-hermes
        ];

        environment = {
          MNEMOSYNE_HOST_LLM_ENABLED = "true";
        };

        settings = {
          memory = {
            provider = "mnemosyne";
            memory_enabled = false;
            user_profile_enabled = false;
          };
        };
      };

      systemd.services.hermes-agent.postStart = ''
        export HERMES_HOME="/var/lib/hermes/.hermes"
        ${lib.getExe pkgs.mnemosyne-hermes} install --force 2> /dev/null
      '';
    })

    (mkIf (cfg.enable && cfg.apiServer.enable) {
      sops = {
        secrets."${cfg.apiServer.tokenReference}" = { };
        templates."HERMES_API_ENV".content = lib.toShellVars {
          API_SERVER_ENABLED = "true";
          API_SERVER_HOST = cfg.apiServer.host;
          API_SERVER_PORT = toString cfg.apiServer.port;
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

    (mkIf (cfg.enable && cfg.voice.enable && cfg.voice.wyoming-stt.enable) {
      services.hermes-agent = {
        environment = {
          HERMES_LOCAL_STT_COMMAND =
            let
              cmd = "${
                inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wyoming-transcribe-client
              }/bin/wyoming-transcribe";
            in
            "${cmd} {input_path} --output-dir {output_dir} --model {model} --language {language} --host ${cfg.voice.wyoming-stt.host} --port ${toString cfg.voice.wyoming-stt.port}";
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

      sops = {
        secrets."${cfg.platform.hassio.tokenReference}" = { };
        templates."HERMES_HASSIO_ENV".content = toShellVars {
          HASS_TOKEN = config.sops.placeholder."${cfg.platform.hassio.tokenReference}";
          HASS_URL = cfg.platform.hassio.url;
        };
      };
    })

    (mkIf (cfg.enable && cfg.dashboard.enable && cfg.dashboard.oidc.enable) {
      assertions = [
        {
          assertion = cfg.dashboard.oidc.issuer != null;
          message = "OIDC issuer must be specified when OIDC authentication is enabled.";
        }
        {
          assertion = cfg.dashboard.oidc.clientId != null;
          message = "OIDC client ID must be specified when OIDC authentication is enabled.";
        }
      ];

      sops.templates."HERMES_DASHBOARD_OIDC_ENV".content = toShellVars {
        HERMES_DASHBOARD_OIDC_ISSUER = cfg.dashboard.oidc.issuer;
        HERMES_DASHBOARD_OIDC_CLIENT_ID = cfg.dashboard.oidc.clientId;
        HERMES_DASHBOARD_OIDC_SCOPES = concatStringsSep " " cfg.dashboard.oidc.scopes;
      };

      services.hermes-agent = {
        environmentFiles = [ config.sops.templates."HERMES_DASHBOARD_OIDC_ENV".path ];
        settings.dashboard.oauth = {
          inherit (cfg.dashboard.oidc) provider;
          "${cfg.dashboard.oidc.provider}" = {
            inherit (cfg.dashboard.oidc) issuer scopes;
            client_id = cfg.dashboard.oidc.clientId;
          };
        };
      };
    })
  ];
}
