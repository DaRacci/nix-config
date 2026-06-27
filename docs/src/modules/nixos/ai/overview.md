# AI Modules

The `modules/nixos/ai/` tree is the canonical home for AI infrastructure services in this NixOS configuration. It provides first-class NixOS modules for AI-related daemons and services that are independent of any specific agent container.

## What belongs in `ai/` vs `services/`

| Location                  | Purpose                       | Examples                                                       |
| ------------------------- | ----------------------------- | -------------------------------------------------------------- |
| `modules/nixos/ai/`       | AI infrastructure daemons     | Mnemosyne sync server, future: LLM gateways, embedding servers |
| `modules/nixos/services/` | Monolithic service containers | AI Agent (Hermes), future: agent orchestration                 |

The `ai/` tree manages standalone services that an AI agent might consume, while `services/` manages the agent container itself.

## Current Modules

- [Mnemosyne](mnemosyne.md) — Sync server, optional MCP server, and sync client orchestration for the Mnemosyne SQLite-based memory provider

## Usage

```nix
{
  services.mnemosyne = {
    enable = true;
    server.sync.enable = true;
  };
}
```

The `ai/` module tree is loaded on all device types by `mkSystem`.
