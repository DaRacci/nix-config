# AI Agent — Hermes Autonomous Agent

## Purpose

Autonomous AI Agent service powered by Hermes, providing intelligent task automation with security controls for code review and development tasks.

## Entry Point

- **Main file**: [ai-agent.nix](../../../../../modules/nixos/services/ai-agent.nix)
- **Upstream**: [Hermes Agent](https://hermes-agent.nousresearch.com/)
- **Package**: The module routes `services.hermes-agent.package` through the local `pkgs.hermes-agent` overlay, which carries a few upstream patches.

The module routes `services.hermes-agent.package` through the local `pkgs.hermes-agent` overlay, which carries the lazy-deps managed-install fix from [PR #48637](https://github.com/NousResearch/hermes-agent/pull/48637). This ensures Hermes fails fast with `FeatureUnavailable` on read-only NixOS installs rather than retrying `ensurepip`.

#### Options

{{#include ../../../../generated/services-ai-agent-options.md}}

## Architecture / Services / Scope

The module enables `services.hermes-agent` (running inside a Docker container) and adds optional components on top:

- **Dashboard** — a separate `hermes-dashboard` systemd service runs `docker exec` into the `hermes-agent` container to serve the dashboard under the `hermes` user. Environment files configured via `services.hermes-agent.environmentFiles` are loaded by systemd's `EnvironmentFile` directive (read as root) and passed into the container via `docker exec --env-file`. The dashboard stays local by default and does not open a browser.
- **Voice & STT** — optional voice input and output. With `services.ai-agent.voice.wyoming-stt.enable`, Hermes reuses an existing Wyoming faster-whisper server instead of running a separate Whisper instance: `HERMES_LOCAL_STT_COMMAND` is set to invoke `wyoming-transcribe`, which sends audio over the Wyoming protocol and returns the transcript. No second Whisper process needed.
- **OIDC Authentication** — optional OpenID Connect authentication for the dashboard using a **public PKCE client** (no `client_secret`). The client ID is a public identifier — it does not need to be stored as a secret. The module generates a `HERMES_DASHBOARD_OIDC_ENV` environment file with the OIDC settings, loaded by the `hermes-dashboard` service.
- **Memory (Mnemosyne)** — with `services.ai-agent.memory.enable`, the memory provider switches from the built-in user profile (USER.md injection) to **Mnemosyne**, a local SQLite-backed memory system with semantic recall (SQLite with FTS5 hybrid ranking + vector search).

## Secrets

Hermes requires API keys via environment files. Configure via sops-nix:

```nix
sops = {
  secrets = {
    "AI_AGENT/OPENROUTER_API_KEY" = { };
  };
  templates."HERMES_ENV".content = ''
    OPENROUTER_API_KEY=${config.sops.placeholder."AI_AGENT/OPENROUTER_API_KEY"}
  '';
};

services.hermes-agent.environmentFiles = [ config.sops.templates."HERMES_ENV".path ];
```

The module itself declares secrets for the enabled optional components:

- API server token (default `AI_AGENT/API_SERVER_TOKEN`) — authenticates the OpenAI-compatible API server.
- Discord bot token (default `AI_AGENT/DISCORD_BOT_TOKEN`) — Discord platform.
- Home Assistant token (default `AI_AGENT/HASSIO_TOKEN`) — Home Assistant platform.
- Dashboard OIDC uses a public PKCE client, so no client secret is stored.

## Operational Notes / Assumptions

### Usage Example

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
  };
}
```

### Voice & STT

Enable voice input and output with `services.ai-agent.voice.enable = true;`. To reuse an existing Wyoming faster-whisper server instead of running a separate Whisper instance:

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
    voice = {
      enable = true;
      wyoming-stt.enable = true;
    };
  };
}
```

### Dashboard & OIDC

Enable the web dashboard with `services.ai-agent.dashboard.enable = true;`, and OIDC authentication with `services.ai-agent.dashboard.oidc.enable = true;`:

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
    dashboard = {
      enable = true;
      publicURL = "https://dashboard.example.com";
      oidc = {
        enable = true;
        provider = "self-hosted";
        issuer = "https://auth.example.com/oauth2/openid/hermes";
        clientId = "hermes";
        scopes = [ "openid" "profile" "email" ];
      };
    };
  };
}
```

### Memory (Mnemosyne)

Enable long-term memory with `services.ai-agent.memory.enable = true;`:

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
    memory.enable = true;
  };
}
```

## References

- [Hermes Agent](https://hermes-agent.nousresearch.com/)
- [Mnemosyne](../ai/mnemosyne.md)
