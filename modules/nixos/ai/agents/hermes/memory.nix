{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  inherit (types) str;

  hlib = import ./lib.nix { inherit lib; };

  mnemosyne-hermes = pkgs.mnemosyne-hermes.overridePythonAttrs (base: {
    dependencies =
      (hlib.depsMinusNamed [ "pyyaml" ] base.dependencies)
      |> (map (dep: if (lib.getName dep) == "mnemosyne-memory" then mnemosyne-memory else dep));
    dontCheckRuntimeDeps = true;
  });
  mnemosyne-memory = pkgs.mnemosyne-memory.overridePythonAttrs (base: {
    dependencies = hlib.depsMinusNamed [ "pyyaml" ] base.dependencies;
    dontCheckRuntimeDeps = true;
  });

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.memory = {
    enable = mkEnableOption ''
      long-term memory

      When enabled this disables the builtin user profile and memory markdown features,
      to nudge the agent towards using the configured long-term memory provider for all memory.
    '';

    tokenReference = mkOption {
      type = str;
      default = "AI_AGENT/MNEMOSYNE_OPENROUTER_API_KEY";
      description = "The reference to the secret containing the OpenRouter API key for Mnemosyne.";
    };
  };

  config = mkIf (cfg.enable && cfg.memory.enable) {
    sops = {
      secrets."${cfg.memory.tokenReference}" = { };
      templates."HERMES_MNEOMSYNE_ENV".content = ''
        MNEMOSYNE_LLM_API_KEY=$__file{${config.sops.secrets."${cfg.memory.tokenReference}".path}}
      '';
    };

    services = {
      hermes-agent = {
        extraPythonPackages = [
          mnemosyne-memory
          mnemosyne-hermes
        ];

        environment = {
          MNEMOSYNE_LLM_CONFLICT_DETECTION = "true";
          MNEMOSYNE_ENHANCED_RECALL = "1";
          MNEMOSYNE_PROACTIVE_LINKING = "1";
          MNEMOSYNE_FACT_RECALL_ENABLED = "1";

          MNEMOSYNE_LLM_MODEL = config.services.ai-agent.models.compression;
          MNEMOSYNE_LLM_BASE_URL = "https://openrouter.ai/api/v1";
          MNEMOSYNE_LLM_MAX_TOKENS = "8192";
          MNEMOSYNE_LLM_N_CTX = "8192";
          MNEMOSYNE_LLM_EXTRA_BODY = ''{"reasoning":{"effort":"low"},"provider":{"require_parameters":true,"quantizations":["fp8"],"sort":"price"}}'';
        };
      };

      ai-agent = {
        settings = {
          memory = {
            provider = "mnemosyne";
            memory_enabled = false;
            user_profile_enabled = false;

            mnemosyne = {
              auto_sleep = true;
              profile_isolation = true;
              shared_surface_read = true;
              sleep_threshold = 5;
              tools = null; # Null means all
            };
          };

          plugins.enabled = [ "mnemosyne" ];
        };
      };
    };
  };
}
