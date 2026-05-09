{
  config,
  lib,
  ...
}:
{
  sops = {
    secrets = {
      "AI_AGENT/OPENROUTER_API_KEY" = { };
      "AI_AGENT/DISCORD_BOT_TOKEN" = { };
    };

    templates."HERMES_ENV".content = lib.toShellVars {
      OPENROUTER_API_KEY = config.sops.placeholder."AI_AGENT/OPENROUTER_API_KEY";
      DISCORD_BOT_TOKEN = config.sops.placeholder."AI_AGENT/DISCORD_BOT_TOKEN";
      DISCORD_ALLOWED_USERS = "613898815447105547";
      DISCORD_HOME_CHANNEL = "634580724158038027";
      SEARXNG_URL = "https://search.racci.dev";
    };
  };

  server.proxy.virtualHosts.agent.extraConfig = ''
    reverse_proxy localhost:8000
  '';

  services = {
    ai-agent = {
      enable = true;
      dashboard.enable = true;
    };

    hermes-agent = {
      environmentFiles = [ config.sops.templates."HERMES_ENV".path ];

      settings = {
        gateway = {
          allow_public_bind = true;
        };

        channels = {
          discord = {
            enabled = true;
          };
          telegram = {
            enabled = true;
          };
        };

        channels_config = {
          discord = {
            allowed_users = [ "613898815447105547" ];
            stream_mode = "partial";
          };
        };

        memory = {
          embedding_model = "default";
        };
      };
    };
  };
}
