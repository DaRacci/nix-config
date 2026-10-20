{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    toShellVars
    types
    ;
  inherit (types) str;

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.platform.hassio = {
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

  config = mkIf (cfg.enable && cfg.platform.hassio.enable) {
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

      services.hermes-agent.environmentFiles = [ config.sops.templates."HERMES_HASSIO_ENV".path ];
    };
  };
}
