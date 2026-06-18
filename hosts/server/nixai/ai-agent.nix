{
  config,
  lib,
  ...
}:
{
  sops = {
    secrets = {
      "AI_AGENT/AZURE_FOUNDRY_API_KEY" = { };
      "AI_AGENT/AZURE_FOUNDRY_BASE_URL" = { };
      "AI_AGENT/OPENROUTER_API_KEY" = { };
      "AI_AGENT/DISCORD_BOT_TOKEN" = { };
      "AI_AGENT/API_SERVER_TOKEN" = { };
    };

    templates."HERMES_ENV".content = lib.toShellVars {
      AZURE_FOUNDRY_API_KEY = config.sops.placeholder."AI_AGENT/AZURE_FOUNDRY_API_KEY";
      AZURE_FOUNDRY_BASE_URL = config.sops.placeholder."AI_AGENT/AZURE_FOUNDRY_BASE_URL";
      OPENROUTER_API_KEY = config.sops.placeholder."AI_AGENT/OPENROUTER_API_KEY";
      SEARXNG_URL = "https://search.racci.dev";
    };
  };

  server.proxy.virtualHosts.agent.extraConfig = ''
    reverse_proxy localhost:${toString config.services.ai-agent.dashboard.port}
  '';

  services = {
    ai-agent = {
      enable = true;
      firecrawl = {
        enable = true;
        # Reuse Firecrawl API key from web.nix instead of creating
        # a separate AI_AGENT/FIRECRAWL_API_KEY secret.
        apiKeyReference = "FIRECRAWL/API_KEY";
      };
      dashboard = {
        enable = true;
        publicURL = "https://agent.racci.dev";

        oidc = {
          enable = true;
          provider = "self-hosted";
          issuer = "https://auth.racci.dev/oauth2/openid/hermes";
          clientId = "hermes";
        };
      };
      apiServer.enable = true;
      voice.enable = true;
      memory.enable = true;

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
