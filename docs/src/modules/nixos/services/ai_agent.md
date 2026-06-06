## AI Agent

Autonomous AI Agent service powered by Hermes, providing intelligent task automation with security controls for code review and development tasks.

- **Entry point**: `modules/nixos/services/ai-agent.nix`
- **Upstream**: [Hermes Agent](https://hermes-agent.nousresearch.com/)

### Special Options

- `services.ai-agent.enable`: Enable the autonomous AI Agent service.

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
