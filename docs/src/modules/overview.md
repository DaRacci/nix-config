# Modules Overview

## Purpose

This section provides an overview of the custom NixOS and Home-Manager modules defined in this repository. These modules allow for modular and reusable configurations across different hosts and users.

## Entry Points

- `modules/nixos/`: Contains NixOS-specific modules.
  - [Core Module](nixos/core/default.md)
    - [Display Manager](nixos/core/display-manager.md)
    - [Remote Desktop & Streaming](nixos/core/remote.md)
  - [Server Module](nixos/server/default.md)
    - [Dashboard Module](nixos/server/dashboard.md)
    - [Network Module](nixos/server/network.md)
    - [Distributed Builds Module](nixos/server/distributed_builds.md)
    - [Database Module](nixos/server/database.md)
    - [Storage Module](nixos/server/storage.md)
    - [Proxy Module](nixos/server/proxy.md)
    - [SSH Module](nixos/server/ssh.md)
  - [NixOS Services](nixos/services/default.md)
    - [AI Agent](nixos/services/ai-agent.md)
    - [Huntress](nixos/services/huntress.md)
    - [MCPO](nixos/services/mcpo.md)
    - [Metrics](nixos/services/metrics.md)
    - [Tailscale](nixos/services/tailscale.md)
- `modules/flake/`: Flake-level modules for cross-host configuration.
  - [Flake Allocations](flake/allocations.md)
- `modules/home-manager/`: Contains Home-Manager-specific modules.
  - [DIY & Making](home-manager/diy.md)
  - [AI Editors & Assistants](home-manager/ai.md)

## Key Options/Knobs

Modules in this repository often expose configuration options under the `device` or custom service namespaces. Refer to the specific module documentation for detailed options.

## Common Workflows

- **Enabling a Module**: Set `services.<name>.enable = true;` or the relevant enable option in your host or home configuration.
- **Configuring a Module**: Use the options defined by the module to customize its behavior.

## References

- [NixOS Modules](https://nixos.org/manual/nixos/stable/index.html#sec-writing-modules)
- [Home-Manager Modules](https://nix-community.github.io/home-manager/index.xhtml#sec-writing-modules)
