# AI Agents — Hermes Autonomous Agent

## Purpose

Autonomous AI Agent service powered by Hermes, providing intelligent task automation with security controls for code review and development tasks.
The module is provider-oriented: `default.nix` holds universal defaults, while each Hermes feature lives in its own file under `hermes/`.

## Entry Point

- **Main file**: [default.nix](../../../../../modules/nixos/ai/agents/default.nix)
- **Hermes features**: [hermes/default.nix](../../../../../modules/nixos/ai/agents/hermes/default.nix)
- **Upstream**: [Hermes Agent](https://github.com/nousresearch/hermes-agent)
- **Package**: The module routes `services.hermes-agent.package` through the local `pkgs.hermes-agent` overlay, which carries a few patches.

### File layout

- `default.nix` — entry point. Declares only universal options shared by every agent backend: `enable` and `models`.
- `hermes/default.nix` — import aggregator. Declares the local `services.ai-agent.settings` option, which deep-merges (with list concatenation) and is emitted once as `services.hermes-agent.settings`.
- `hermes/lib.nix` — shared helpers: the deep-merge option type and `depsMinusNamed` dependency trimming.
- `hermes/core.nix` — the agent container plus universal agent settings (models wiring, auxiliary models, display, security, approvals, …).
- `hermes/dashboard.nix`, `hermes/dashboard-oidc.nix` — web dashboard unit and OIDC authentication.
- `hermes/api-server.nix` — OpenAI-compatible API server and its environment file.
- `hermes/voice.nix` — voice input/output via Wyoming STT.
- `hermes/memory.nix` — Mnemosyne long-term memory provider.
- `hermes/plugins.nix`, `hermes/scraper.nix`, `hermes/browser.nix` — the `services.ai-agent.extras.*` features.
- `hermes/platform-discord.nix`, `hermes/platform-hassio.nix`, `hermes/platform-webhook.nix` — messaging platforms.
- `hermes/post-start.nix` — `services.ai-agent.containerPostStart` commands.

#### Options

{{#include ../../../../generated/ai-agents-options.md}}

## Architecture / Services / Scope

The module enables `services.hermes-agent` and adds optional components on top:

- **Dashboard** — a separate `hermes-dashboard` systemd service runs `docker exec` into the `hermes-agent` container to serve the dashboard under the `hermes` user.
- **Voice & STT** — optional voice input and output. With `services.ai-agent.voice.wyoming-stt.enable`, Hermes reuses an existing Wyoming faster-whisper server instead of running a separate Whisper instance: `HERMES_LOCAL_STT_COMMAND` is set to invoke `wyoming-transcribe`, which sends audio over the Wyoming protocol and returns the transcript.
- **OIDC Authentication** — optional OpenID Connect authentication for the dashboard using a **public PKCE client**.
- **Memory (Mnemosyne)** — with `services.ai-agent.memory.enable`, the memory provider switches to **Mnemosyne**, a local SQLite-backed memory system with semantic recall.

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

Enable voice input and output with `services.ai-agent.voice.enable = true;`.
To reuse an existing Wyoming faster-whisper server instead of running a separate Whisper instance:

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

This registers the `mnemosyne-hermes` plugin and writes these `settings.memory.mnemosyne` defaults:

- `auto_sleep = true` with `sleep_threshold = 50` — working memory is consolidated into the episodic store once the threshold is reached.
- `profile_isolation = true` — every Hermes profile in the container has its own bank at `mnemosyne/data/banks/<profile>/mnemosyne.db`.
- `shared_surface_read = true` — `mnemosyne_recall` merges shared-surface results into private-bank recall and tags each result with its origin.
- `tools = null` — expose every `mnemosyne_*` tool.

## References

- [Hermes Agent](https://hermes-agent.nousresearch.com/)
- [Mnemosyne](mnemosyne.md)
- [NixAI host](../../../hosts/server/nixai.md)
