{
  config,
  pkgs,
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

      "MCP/N8N_API_KEY" = { };
    };

    templates."HERMES_ENV".content = lib.toShellVars {
      AZURE_FOUNDRY_API_KEY = config.sops.placeholder."AI_AGENT/AZURE_FOUNDRY_API_KEY";
      AZURE_FOUNDRY_BASE_URL = config.sops.placeholder."AI_AGENT/AZURE_FOUNDRY_BASE_URL";
      OPENROUTER_API_KEY = config.sops.placeholder."AI_AGENT/OPENROUTER_API_KEY";
      SEARXNG_URL = "https://search.racci.dev";

      N8N_BASE_URL = "https://n8n.racci.dev";
      N8N_API_KEY = config.sops.placeholder."MCP/N8N_API_KEY";
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
      settings = {
        timezone = config.time.timeZone;
        display.pet = {
          enabled = false;
          slug = "megumin";
        };
      };
      environmentFiles = [ config.sops.templates."HERMES_ENV".path ];
      environment = {
        MNEMOSYNE_SYNC_REMOTE = "http://127.0.0.1:8765";
        MNEMOSYNE_SYNC_KEY_FILE = "file:${config.sops.secrets.MNEMOSYNE_SYNC_KEY.path}";
      };
    };
  };

  services.ai-agent.containerPostStart = [
    {
      command = "${pkgs.docker}/bin/docker cp /etc/ssh/authorized_keys.d/root hermes-agent:/home/hermes/.ssh/authorized_keys";
      host = true;
    }
    ''
      # Privilege separation
      getent passwd sshd >/dev/null 2>&1 || useradd -r -s /sbin/nologin -d /var/empty -M sshd
      mkdir -p /var/empty && chmod 755 /var/empty

      # Host keys
      ${pkgs.openssh}/bin/ssh-keygen -A

      # Config — reads directly from /home/hermes/.ssh/authorized_keys
      cat > /etc/ssh/sshd_config_hermes <<'SSHDCFG'
      Port 2222
      ListenAddress 0.0.0.0
      HostKey /etc/ssh/ssh_host_ed25519_key
      HostKey /etc/ssh/ssh_host_rsa_key
      HostKey /etc/ssh/ssh_host_ecdsa_key
      PubkeyAuthentication yes
      AuthorizedKeysFile .ssh/authorized_keys
      PasswordAuthentication no
      ChallengeResponseAuthentication no
      UsePAM no
      X11Forwarding no
      PrintMotd no
      ClientAliveInterval 60
      ClientAliveCountMax 3
      LogLevel VERBOSE
      SSHDCFG

      passwd -d hermes 2>/dev/null || true

      touch /etc/ssh/.provisioned
    ''

    ''
      pkill -f "sshd.*-f /etc/ssh/sshd_config_hermes" 2>/dev/null || true
      sleep 1
      ${pkgs.openssh}/bin/sshd -f /etc/ssh/sshd_config_hermes -E /tmp/sshd-container.log
    ''
  ];

  server.network.openPortsForSubnet.tcp = [ 2222 ];
}
