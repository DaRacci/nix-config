# NixOS Modules — Overview

## Purpose

This section covers all NixOS modules provided by this flake, including core baseline configuration, server orchestration, custom services, and AI infrastructure.

## Entry Point

- **Main file**: `modules/nixos/default.nix`

## Architecture / Services / Scope

Modules are categorized into directories based on their target:

- `core/`: Shared baselines for all hosts.
- `server/`: Cluster-aware server modules.
- `services/`: Custom NixOS services (e.g., Dashy, Tailscale).
- `ai/`: AI infrastructure daemons.

## References

- [Core Modules](core/default.md)
- [Server Modules](server/default.md)
- [Services Modules](services/default.md)
- [AI Modules](ai/overview.md)
