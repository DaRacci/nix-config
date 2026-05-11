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
      "AI_AGENT/API_SERVER_TOKEN" = { };
    };

    templates."HERMES_ENV".content = lib.toShellVars {
      OPENROUTER_API_KEY = config.sops.placeholder."AI_AGENT/OPENROUTER_API_KEY";
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
      apiServer.enable = true;

      platform = {
        discord = {
          enable = true;
          tokenReference = "AI_AGENT/DISCORD_BOT_TOKEN";
          homeChannel = "634580724158038027";
          allowedUsers = [ "613898815447105547" ];
        };

        hassio = {
          enable = true;
          url = "https://hassio.racci.dev";
        };
      };
    };

    hermes-agent = {
      settings.timezone = "Australia/Sydney";
      environmentFiles = [ config.sops.templates."HERMES_ENV".path ];
    };
  };
}
