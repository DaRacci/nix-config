# NixOS Services — Overview

## Purpose

This section documents the custom NixOS service modules available in this configuration. These modules provide specialised integrations and monitoring capabilities.

## Entry Point

- **Main file**: `modules/nixos/services/default.nix`

## Architecture / Services / Scope

Nested service modules emit generated fragments for options, which are included in their respective documentation pages.

## Operational Notes / Assumptions

- Services should be toggled per-host.

## References

- [AI Agent](ai_agent.md)
- [Huntress](huntress.md)
- [MCPO](mcpo.md)
- [Metrics](metrics.md)
- [Tailscale](tailscale.md)
