{
  config,
  lib,
  ...
}:
let
  cfg = config.services.ai-agent;
in
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

  server.proxy.virtualHosts.agent = {
    public = true;

    ports = [
      cfg.apiServer.port
      cfg.dashboard.port
      config.services.ai-agent.platform.webhook.port
    ];

    extraConfig = ''
      redir /v1 /v1/
      redir /webhook /webhook/

      @apiRequest {
        path /v1*
        method POST
        header Authorization *
        client_ip private_ranges
      }

      handle @apiRequest {
        reverse_proxy localhost:${toString config.services.ai-agent.apiServer.port}
      }

      @webhookRequest {
        path /webhook*
        method POST
      }

      handle @webhookRequest {
          reverse_proxy localhost:${toString config.services.ai-agent.platform.webhook.port}
      }

      @remainingWebhookOrApiRequest {
        path /webhook*
        path /v1*
      }

      handle @remainingWebhookOrApiRequest {
        respond "Unauthorized" 401
      }

      handle {
        reverse_proxy localhost:${toString config.services.ai-agent.dashboard.port}
      }
    '';
  };

  services = {
    ai-agent = {
      enable = true;
      memory.enable = true;
      apiServer.enable = true;

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

      voice = {
        enable = true;
        wyoming-stt.enable = true;
      };

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
      environment = {
        MNEMOSYNE_SYNC_REMOTE = "http://127.0.0.1:8765";
        MNEMOSYNE_SYNC_KEY_FILE = "file:${config.sops.secrets.MNEMOSYNE_SYNC_KEY.path}";
      };
    };
  };
}
