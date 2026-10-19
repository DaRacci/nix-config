{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

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
  options.services.ai-agent.memory.enable = mkEnableOption ''
    long-term memory

    When enabled this disables the builtin user profile and memory markdown features,
    to nudge the agent towards using the configured long-term memory provider for all memory.
  '';

  config = mkIf (cfg.enable && cfg.memory.enable) {
    services = {
      hermes-agent = {
        extraPythonPackages = [
          mnemosyne-memory
          mnemosyne-hermes
        ];

        environment = {
          MNEMOSYNE_LLM_ENABLED = "true";
          MNEMOSYNE_HOST_LLM_ENABLED = "true";
          MNEMOSYNE_USE_CAVEMAN = "true";
          MNEMOSYNE_AUTO_SLEEP_ENABLED = "true";
          MNEMOSYNE_LLM_CONFLICT_DETECTION = "true";
          MNEMOSYNE_ENHANCED_RECALL = "1";
          MNEMOSYNE_PROACTIVE_LINKING = "1";
          MNEMOSYNE_FACT_RECALL_ENABLED = "1";
        };
      };

      ai-agent = {
        settings = {
          memory = {
            provider = "mnemosyne";
            memory_enabled = lib.mkForce false;
            user_profile_enabled = lib.mkForce false;

            mnemosyne = {
              auto_sleep = true;
              profile_isolation = false;
              shared_surface_read = true;
              sleep_threshold = 50;
              tools = null; # Null means all
            };
          };

          plugins.enabled = [ "mnemosyne" ];
        };
      };
    };
  };
}
