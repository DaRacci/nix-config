# AI Agent — Hermes Autonomous Agent

## Purpose

Autonomous AI Agent service powered by Hermes, providing intelligent task automation with security controls for code review and development tasks.

## Entry Point

- **Main file**: [ai-agent.nix](../../../../../modules/nixos/services/ai-agent.nix)
- **Upstream**: [Hermes Agent](https://hermes-agent.nousresearch.com/)
- **Package**: The module routes `services.hermes-agent.package` through the local `pkgs.hermes-agent` overlay, which carries a few upstream patches.

#### Options

{{#include ../../../../generated/services-ai-agent-options.md}}

## Architecture / Services / Scope

The module enables `services.hermes-agent` (running inside a Docker container) and adds optional components on top:

- **Dashboard** — a separate `hermes-dashboard` systemd service runs `docker exec` into the `hermes-agent` container to serve the dashboard under the `hermes` user. Environment files configured via `services.hermes-agent.environmentFiles` are loaded by systemd's `EnvironmentFile` directive (read as root) and passed into the container via `docker exec --env-file`. The dashboard stays local by default and does not open a browser. Because `hermes-agent.service` is `Type=simple` (systemd marks it started as soon as `docker start -a` is spawned, _before_ the container is up), the dashboard gates its start on an `ExecStartPre` readiness loop that waits for `docker exec … hermes-agent true` to succeed (300s readiness budget, with the unit's start timeout set 30s above it so the loop can always report the failure itself, and the last `docker exec` error kept for the log), and it sets `StartLimitIntervalSec = 0` so `Restart=always` keeps retrying instead of being throttled into a permanent `failed` state when it races a container (re)creation.
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

This registers the `mnemosyne-hermes` plugin and writes these `settings.memory.mnemosyne` defaults:

- `auto_sleep = true` with `sleep_threshold = 50` — working memory is consolidated into the episodic store once the threshold is reached.
- `profile_isolation = false` — every Hermes profile in the container shares the single default bank at `$HERMES_HOME/mnemosyne/data/mnemosyne.db`, which is where the existing memory history lives. Setting it to `true` instead gives each profile its own `mnemosyne/data/banks/<profile>/mnemosyne.db`; banks are not migrated between the two modes.
- `shared_surface_read = true` — `mnemosyne_recall` merges shared-surface results into private-bank recall and tags each result with its origin.
- `tools = null` — expose every `mnemosyne_*` tool.

### GitHub CLI for PR-contract cards

Cards whose completion contract is a pull request are verified by `hermes_cli/kanban_pr_acceptance.py`, which needs a `gh` that supports `gh api --slurp` and a gh identity for the card's assignee profile. Both are container-local, so they belong in `services.ai-agent.containerPostStart`: a host that can own PR-contract cards provisions a `gh` that precedes `/usr/bin` on the container PATH, and links `/data/.hermes/profiles/<profile>/gh` to the fleet gh config for every profile.

The [`nixai`](../../../hosts/server/nixai.md) host implements both; that page documents the pinned version and digest, the profile onboarding rule, and why a nix `pkgs.gh` cannot be used here (`services.hermes-agent` appends nix store tools to `PATH` with `--suffix`, so `/usr/bin/gh` always wins).

## References

- [Hermes Agent](https://hermes-agent.nousresearch.com/)
- [Mnemosyne](../ai/mnemosyne.md)
