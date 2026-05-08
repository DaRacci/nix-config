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
    mkOption
    mkEnableOption
    ;
  inherit (types) str;

  cfg = config.services.ai-agent;
in
{
  imports = optional importExternals inputs.hermes-agent.nixosModules.default;

  options.services.ai-agent = {
    enable = mkEnableOption "autonomous AI Agent service";

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

  config = mkIf cfg.enable {
    services.hermes-agent = {
      enable = true;
      container.enable = true;

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
          backend = "docker";
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
  };
}
