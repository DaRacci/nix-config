{
  config,
  ...
}:
{
  sops = {
    secrets = {
      "AI_AGENT/DISCORD_BOT_TOKEN" = { };
      "AI_AGENT/OPENROUTER_API_KEY" = { };
    };

    templates."ZEROCLAW_ENV".content = ''
      OPENROUTER_API_KEY=${config.sops.placeholder."AI_AGENT/OPENROUTER_API_KEY"}
    '';
  };

  server.proxy.virtualHosts.agent.extraConfig = ''
    reverse_proxy localhost:${toString config.services.zeroclaw.port}
  '';

  services = {
    ai-agent.enable = true;
    zeroclaw = {
      host = "0.0.0.0";
      environmentFile = config.sops.templates."ZEROCLAW_ENV".path;
      settings = {
        gateway.allow_public_bind = true;

        default_provider = "copilot";
        default_model = "gpt-5-mini";

        model_routes = [
          {
            hint = "reasoning";
            provider = "copilot";
            model = "claude-sonnet-4.6";
          }
          {
            hint = "cost-optimized";
            provider = "copilot";
            model = "gpt-5-mini";
          }
          {
            hint = "fast";
            provider = "copilot";
            model = "grok-code-fast-1";
          }
          {
            hint = "standard";
            provider = "copilot";
            model = "claude-haiku-4.5";
          }
        ];

        embedding_routes = [
          {
            hint = "semantic";
            provider = "custom:http://localhost:11434/api/embeddings";
            model = "nomic-embed-text-v2-moe:latest";
            embedding_dimensions = 768;
          }
        ];

        reliability = {
          fallback_providers = [
            "openrouter"
            "ollama"
          ];

          model_fallbacks = {
            "gpt-5-mini" = [
              "gpt-4.1"
              "gpt-4o"
            ];

          };
        };

        channels_config.discord = {
          allowed_users = [ "613898815447105547" ];
          stream_mode = "partial";
        };

        memory = {
          embedding_model = "hint:semantic";
        };

        mcp = {
          enabled = true;
          servers = [

          ];
        };
      };

      channels.discord = {
        secretFiles.bot_token = "/run/credentials/zeroclaw.service/discord-token";
      };
    };
  };

  systemd.services.zeroclaw.serviceConfig = {
    LoadCredential = [ "discord-token:${config.sops.secrets."AI_AGENT/DISCORD_BOT_TOKEN".path}" ];
  };
}
