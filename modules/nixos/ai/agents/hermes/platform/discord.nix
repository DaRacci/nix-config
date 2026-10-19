{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    toShellVars
    types
    ;
  inherit (types) listOf nullOr str;

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.platform.discord = {
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

  config = mkIf (cfg.enable && cfg.platform.discord.enable) {
    sops = {
      secrets."${cfg.platform.discord.tokenReference}" = { };
      templates."HERMES_DISCORD_ENV".content = toShellVars {
        DISCORD_BOT_TOKEN = config.sops.placeholder."${cfg.platform.discord.tokenReference}";
        DISCORD_ALLOWED_USERS = concatStringsSep " " cfg.platform.discord.allowedUsers;
        DISCORD_HOME_CHANNEL = cfg.platform.discord.homeChannel;
      };
    };

    services = {
      hermes-agent.environmentFiles = [ config.sops.templates."HERMES_DISCORD_ENV".path ];

      ai-agent.settings.discord = {
        auto_thread = true;
        require_mention = true;
      };
    };
  };
}
