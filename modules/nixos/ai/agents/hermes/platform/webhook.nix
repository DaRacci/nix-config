{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    mkEnableOption
    types
    ;
  inherit (types) int;

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.platform.webhook = {
    enable = mkEnableOption "the webhook listener for the agent";

    port = mkOption {
      type = int;
      default = 8654;
      description = "The port for the webhook listener to listen on.";
    };
  };

  config = mkIf (cfg.enable && cfg.platform.webhook.enable) {
    services.ai-agent.settings.platforms.webhook = {
      enabled = true;

      extra = {
        port = cfg.platform.webhook.port;
        rate_limit = 30;
      };
    };
  };
}
