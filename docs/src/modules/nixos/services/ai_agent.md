## AI Agent

Autonomous AI Agent service powered by Hermes, providing intelligent task automation with security controls for code review and development tasks.

- **Entry point**: `modules/nixos/services/ai-agent.nix`
- **Upstream**: [Hermes Agent](https://hermes-agent.nousresearch.com/)

### Special Options

- `services.ai-agent.enable`: Enable the autonomous AI Agent service.

### Configuration

The Hermes agent is configured with the following defaults:

- **Model**: `tencent/hy3-preview:free` via OpenRouter
- **Toolsets**: `hermes-cli`
- **Max Turns**: 150
- **Terminal Backend**: Docker with `nikolaik/python-nodejs:python3.11-nodejs20`
- **Compression**: Enabled with threshold `0.5`
- **Memory**: Enabled with user profiles
- **Display**: Full UI with `kawaii` personality
- **Security**: Hermes redaction + Tirith enabled
- **MCP**: Filesystem server available

#### Model Configuration

```nix
services.hermes-agent.settings.model = {
  base_url = "https://openrouter.ai/api/v1";
  default = "anthropic/claude-sonnet-4-20250514";
};
```

Supported providers:

- **OpenRouter** (default): `https://openrouter.ai/api/v1`
- **Anthropic**: `https://api.anthropic.com`
- **OpenAI**: `https://api.openai.com/v1`

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

### Messaging Channels

Hermes supports multiple messaging platforms:

#### Discord

```nix
services.hermes-agent.settings.channels.discord.enabled = true;
services.hermes-agent.settings.channels_config.discord = {
  allowed_users = [ "613898815447105547" ];
  stream_mode = "partial";
};
```

#### Telegram

```nix
services.hermes-agent.settings.channels.telegram.enabled = true;
```

### MCP Servers

Configure MCP (Model Context Protocol) servers:

```nix
services.hermes-agent.mcpServers = {
  filesystem = {
    command = "npx";
    args = [ "-y" "@modelcontextprotocol/server-filesystem" "/data/workspace" ];
  };
};
```

### Usage Example

```nix
{ ... }: {
  services.ai-agent = {
    enable = true;
  };
}
```

### Operational Notes

The Hermes agent service provides:

- Declarative configuration via NixOS
- Hardened systemd service with security controls
- Multiple messaging channel support (Discord, Telegram)
- MCP server integration
- Memory and user profile persistence
- Gateway service for incoming messages

The service runs as the `hermes` user with state in `/var/lib/hermes/`. Use `hermes` CLI (when `addToSystemPackages = true`) to interact with the agent.
