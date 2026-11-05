{
  self,
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkAfter
    mkIf
    ;

  modelLib = import "${self}/modules/fragments/ai/models/lib.nix" { inherit lib; };

  cfg = config.services.ai-agent;
  models = config.ai.models;
  hermes = config.services.hermes-agent;

  primaryChain = modelLib.resolveChain models.primary;
  visionChain = modelLib.resolveChain models.vision;
  compressionChain = modelLib.resolveChain models.compression;
  simpletonChain = modelLib.resolveChain models.simpleton;
  brainsChain = modelLib.resolveChain models.brains;

  auxiliaryModel = chain: {
    provider = modelLib.providerName "hermes" chain.primary.provider;
    inherit (chain.primary) model;
    fallback_chain = modelLib.mapFallbacks "hermes" chain.fallbacks;
  };
in
{
  config = mkIf cfg.enable {
    services = {
      hermes-agent = {
        enable = true;
        package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
        container.enable = true;

        extraDependencyGroups = [
          "acp"
          "messaging"
          "voice"
          "youtube"
        ];

        environment = {
          BASH_ENV = "/home/hermes/.bashrc";
          HOME = "/home/hermes"; # For some reason this is getting set to /var/lib/hermes inside the container
          SUDO_PASSWORD = ""; # Container has no password but still prompts, this disables the prompt.
        };

        inherit (cfg) settings;
      };

      ai-agent.settings = {
        gateway = {
          multiplex_profiles = true;
        };

        model = {
          provider = modelLib.providerName "hermes" primaryChain.primary.provider;
          base_url = modelLib.providerBaseUrls.${primaryChain.primary.provider};
          default = primaryChain.primary.model;
        };

        fallback_providers = modelLib.mapFallbacks "hermes" primaryChain.fallbacks;

        toolsets = [ "all" ];
        checkpoints.enabled = true;
        code_execution.mode = "project";

        plugins.enabled = [
          # Builtins
          "security-guidance"
          "disk-cleanup"
        ];

        cron = {
          script_timeout_seconds = 3600;
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
          # this just breaks so much.
          verify_on_stop = false;

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
          approval = auxiliaryModel simpletonChain;
          compression = auxiliaryModel compressionChain;
          curator = auxiliaryModel simpletonChain;
          session_search = auxiliaryModel simpletonChain;
          title_generation = auxiliaryModel compressionChain;
          triage_specifier = auxiliaryModel brainsChain;
          vision = auxiliaryModel visionChain;
        };

        delegation = {
          max_concurrent_children = 24;
          max_spawn_depth = 3;
          provider = modelLib.providerName "hermes" primaryChain.primary.provider;
          inherit (primaryChain.primary) model;
          fallback_providers = modelLib.mapFallbacks "hermes" primaryChain.fallbacks;
        };

        terminal = {
          backend = "local";
          container_persistent = true;
          persistent_shell = true;
        };

        compression = {
          enabled = true;
          tail_mode = "lean";
          idle_compact_after_seconds = 1800;
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
          skin = "slate";
          language = "en";
          tool_progress = "all";
        };

        sessions = {
          auto_archive = true;
          auto_archive_days = 7;
        };

        streaming = {
          enabled = true;
          transport = "edit";
        };

        memory = {
          memory_enabled = !cfg.memory.enable;
          user_profile_enabled = !cfg.memory.enable;
        };

        privacy.redact_pii = true;

        security = {
          redact_secrets = true;
          tirith_enabled = true;
          tirith_path = lib.getExe pkgs.tirith;
          tirith_timeout = 5;
          tirith_fail_open = false;
        };

        approvals = {
          mode = "smart";
          timeout = 60;
          cron_mode = "deny";
          mcp_reload_confirm = true;
        };
      };
    };

    # The gateway client refuses a control directory another user can write
    # (home_mode_unsafe in hermes_cli/gateway_runtime_discovery.py), while the
    # upstream module creates this one 2770 so container hostUsers can share it.
    # `z` and not `d`: tmpfiles drops a second `d` line for a path that exists.
    systemd.tmpfiles.rules = mkAfter [
      "z ${hermes.stateDir}/.hermes 0750 ${hermes.user} ${hermes.group} - -"
    ];
  };
}
