{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.ai-agent;

  # gh release installed into the container's /usr/local/bin so it precedes the
  # base image's /usr/bin/gh (see the containerPostStart hooks below). 2.102.0 is
  # the release verified to support `gh api --slurp`, which the kanban
  # PR-acceptance gate passes; the tarball digests come from that release's
  # gh_2.102.0_checksums.txt.
  ghVersion = "2.102.0";

  ghArch =
    {
      x86_64-linux = "amd64";
      aarch64-linux = "arm64";
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "no gh release tarball is defined for ${pkgs.stdenv.hostPlatform.system}");

  ghTarballHash =
    {
      amd64 = "bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386";
      arm64 = "7862c86c72f43df3a2d93ddde6f473285b4e2af61b494849846827e513ef6484";
    }
    .${ghArch};
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

      @profileWebhookRequest {
        path /p/*/webhooks/*
        method POST
      }

      handle @profileWebhookRequest {
          reverse_proxy localhost:${toString config.services.ai-agent.platform.webhook.port}
      }

      @remainingWebhookOrApiRequest {
        path /webhook*
        path /p/*/webhooks*
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

      extras = {
        plugins = true;
        scraper = {
          enable = true;
          searxEndpoint = "https://search.racci.dev";
        };
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
      touch /home/hermes/.profile
      grep -q '^export HERMES_HOME=' /home/hermes/.profile \
        || echo 'export HERMES_HOME=/data/.hermes' >> /home/hermes/.profile
    ''

    ''
      pkill -f "sshd.*-f /etc/ssh/sshd_config_hermes" 2>/dev/null || true
      sleep 1
      ${pkgs.openssh}/bin/sshd -f /etc/ssh/sshd_config_hermes -E /tmp/sshd-container.log
    ''

    # The kanban PR-acceptance gate runs `gh api … --paginate --slurp`, which the
    # base image's gh 2.45.0 at /usr/bin/gh rejects. Install to /usr/local/bin so
    # the gate's PATH lookup finds this gh first. A nix pkgs.gh cannot be used for
    # this: the hermes-agent wrapper appends nix store tools to PATH with
    # `--suffix`, so every /nix/store path sorts after /usr/bin and the distro gh
    # always wins. This hook runs on every container start, so it skips the
    # download whenever the installed gh already supports the flag.
    ''
      GH_BIN=/usr/local/bin/gh
      if [ -x "$GH_BIN" ] && "$GH_BIN" api --help 2>&1 | grep -q -- '--slurp'; then
        echo "[post-start] $("$GH_BIN" --version | head -n 1) at $GH_BIN already supports --slurp"
      else
        GH_TMP=$(mktemp -d)
        trap 'rm -rf "$GH_TMP"' EXIT
        GH_URL="https://github.com/cli/cli/releases/download/v${ghVersion}/gh_${ghVersion}_linux_${ghArch}.tar.gz"
        echo "[post-start] installing gh ${ghVersion} from $GH_URL"
        curl -fsSL -o "$GH_TMP/gh.tar.gz" "$GH_URL"
        printf '%s  %s\n' "${ghTarballHash}" "$GH_TMP/gh.tar.gz" | sha256sum -c -
        tar -xzf "$GH_TMP/gh.tar.gz" -C "$GH_TMP"
        install -m 0755 "$GH_TMP/gh_${ghVersion}_linux_${ghArch}/bin/gh" "$GH_BIN"
        echo "[post-start] installed $("$GH_BIN" --version | head -n 1) at $GH_BIN"
      fi
    ''

    # Every profile that can be assigned a PR-contract card needs a gh identity:
    # the acceptance gate reads GitHub as the assignee profile and pins
    # GH_CONFIG_DIR to <profile>/gh whenever that profile's environment carries no
    # GH_TOKEN, GITHUB_TOKEN or GH_CONFIG_DIR. The fleet has a single GitHub
    # identity (RacciDev-Bot) at /home/hermes/.config/gh, so link any profile that
    # does not have one yet. This is the profile onboarding rule: it is re-asserted
    # on every container start, so a profile created at any point can never be
    # missing it. Existing links are left untouched, so a profile that points at a
    # distinct login is not overwritten.
    ''
      GH_CONFIG=/home/hermes/.config/gh
      if [ ! -e "$GH_CONFIG" ]; then
        echo "[post-start] warning: $GH_CONFIG is missing; per-profile gh logins will fail until it is provisioned" >&2
      fi
      for PROFILE_DIR in /data/.hermes/profiles/*; do
        [ -d "$PROFILE_DIR" ] || continue
        GH_LINK="$PROFILE_DIR/gh"
        if [ ! -e "$GH_LINK" ] && [ ! -L "$GH_LINK" ]; then
          ln -s "$GH_CONFIG" "$GH_LINK"
          echo "[post-start] linked $GH_LINK -> $GH_CONFIG"
        fi
      done
    ''
  ];

  server.network.openPortsForSubnet.tcp = [ 2222 ];
}
