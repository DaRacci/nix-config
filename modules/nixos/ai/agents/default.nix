{
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    ;
  inherit (types) str enum;
in
{
  imports = [ ./hermes ];

  options.services.ai-agent = {
    enable = mkEnableOption "autonomous AI Agent service";

    models = {
      provider = mkOption {
        type = enum [ "openrouter" ];
        default = "openrouter";
        description = "The model provider to use.";
      };

      primary = mkOption {
        type = str;
        default = "~deepseek/deepseek-v4-flash-latest";
        description = "The primary language model to use for the AI agent.";
      };

      vision = mkOption {
        type = str;
        default = "xiaomi/mimo-v2.5";
        description = "The vision model to delegate image understanding tasks to.";
      };

      compression = mkOption {
        type = str;
        default = "~deepseek/deepseek-v4-flash-latest";
        description = ''
          The model to use for compression of context, summorisation and similar tasks that don't require reasoning.
          This model still needs a decently sized context window to be effective.
        '';
      };

      simpleton = mkOption {
        type = str;
        default = "inclusionai/ling-3.0-flash";
        description = ''
          The simpleton model to delegate tasks to that require less reasoning, basic understanding and small context windows.
        '';
      };

      brains = mkOption {
        type = str;
        default = "deepseek/deepseek-v4-pro-0813";
        description = ''
          The smartest model to use for complex reasoning and decision-making tasks.
        '';
      };
    };
  };
}
