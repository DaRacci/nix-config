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
