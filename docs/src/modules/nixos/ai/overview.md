# AI Modules — Overview

## Purpose

The `modules/nixos/ai/` tree is the canonical home for AI infrastructure services in this NixOS configuration.
It provides first-class NixOS modules for AI-related daemons and services that are independent of any specific agent container.

## Entry Point

- **Main file**: `modules/nixos/ai/default.nix`

## Architecture / Services / Scope

### What belongs in `ai/`

| Location                     | Purpose                           | Examples                                                |
| ---------------------------- | --------------------------------- | ------------------------------------------------------- |
| `modules/nixos/ai/agents/`   | Agent container modules           | AI Agent, with per-feature files under `agents/hermes/` |
| `modules/nixos/ai/services/` | AI infrastructure/sidecar daemons | Mnemosyne sync server, MCPO                             |

The `ai/` tree owns both the agent container and the standalone services it consumes.

## References

- [Agents](agents.md) — Hermes autonomous agent container and its per-feature modules
- [Mnemosyne](mnemosyne.md) — Sync server, optional MCP server, and sync client orchestration for the Mnemosyne SQLite-based memory provider
