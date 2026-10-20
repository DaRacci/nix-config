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
  inherit (types) int str;

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.platform.apiServer = {
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

  config = mkIf (cfg.enable && cfg.platform.apiServer.enable) {
    sops = {
      secrets."${cfg.platform.apiServer.tokenReference}" = { };
      templates."HERMES_API_ENV".content = toShellVars {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = cfg.platform.apiServer.host;
        API_SERVER_PORT = toString cfg.platform.apiServer.port;
        API_SERVER_KEY = config.sops.placeholder."${cfg.platform.apiServer.tokenReference}";
      };
    };

    services.hermes-agent.environmentFiles = [ config.sops.templates."HERMES_API_ENV".path ];
  };
}
