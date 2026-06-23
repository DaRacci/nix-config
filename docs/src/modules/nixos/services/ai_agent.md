## AI Agent

Autonomous AI Agent service powered by Hermes, providing intelligent task automation with security controls for code review and development tasks.

- **Entry point**: `modules/nixos/services/ai-agent.nix`
- **Upstream**: [Hermes Agent](https://hermes-agent.nousresearch.com/)

### Options

{{#include ../../../../generated/services-ai-agent-options.md}}

### Secrets Management

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

services.hermes-agent.environmentFile = config.sops.templates."HERMES_ENV".path;
```

### Usage Example

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
  };
}
```

### Firecrawl Integration

Enable Firecrawl as the web extraction backend. The module injects `FIRECRAWL_API_URL` and `FIRECRAWL_API_KEY` into the Hermes agent environment.

You can reuse an existing `FIRECRAWL/API_KEY` sops secret by pointing `apiKeyReference` at it, avoiding duplicate secrets:

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
    firecrawl = {
      enable = true;
      # Reuse secret declared elsewhere (e.g. in web.nix)
      apiKeyReference = "FIRECRAWL/API_KEY";
    };
  };
}
```

If you want a dedicated secret, omit `apiKeyReference` and it defaults to `AI_AGENT/FIRECRAWL_API_KEY`. The module will create that sops secret automatically.

`url` (mapped to `FIRECRAWL_API_URL`) defaults to `http://127.0.0.1:3002` (local Firecrawl). Override if Firecrawl lives elsewhere:

### Dashboard Service

Enable the web dashboard with `services.ai-agent.dashboard.enable = true;`.

This adds a separate `hermes-dashboard` systemd service that runs `hermes dashboard --host 127.0.0.1 --no-open` under the `hermes` user. The dashboard stays local by default and does not open a browser.

### OIDC Authentication

Enable OpenID Connect authentication for the dashboard with `services.ai-agent.dashboard.oidc.enable = true;`.

The dashboard uses a **public PKCE client** (no client_secret). The client ID is a public identifier — it does not need to be stored as a secret.

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

The module generates a `HERMES_DASHBOARD_OIDC_ENV` environment file with the OIDC settings, which is loaded by the `hermes-dashboard` service.
