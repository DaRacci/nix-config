# Modules Overview

## Purpose

This section provides an overview of the custom NixOS and Home-Manager modules defined in this repository. These modules allow for modular and reusable configurations across different hosts and users.

## Entry Points

- `modules/nixos/`: Contains NixOS-specific modules.
  - `Core Module`
    - [Display Manager](nixos/core/display_manager.md)
    - [Remote Desktop & Streaming](nixos/core/remote.md)
    - [Virtualisation](nixos/core/virtualisation.md)
  - [Server Module](nixos/server/default.md)
    - [Dashboard Module](nixos/server/dashboard.md)
    - [Network Module](nixos/server/network.md)
    - [Distributed Builds Module](nixos/server/distributed_builds.md)
    - [Database Module](nixos/server/database.md)
    - [Storage Module](nixos/server/storage.md)
    - [Proxy Module](nixos/server/proxy.md)
    - [SSH Module](nixos/server/ssh.md)
  - [Services](nixos/services/default.md)
    - [AI Agent](nixos/services/ai_agent.md)
    - [Huntress](nixos/services/huntress.md)
    - [MCPO](nixos/services/mcpo.md)
    - [Metrics](nixos/services/metrics.md)
    - [Tailscale](nixos/services/tailscale.md)
    - [Woodpecker Nix](nixos/services/woodpecker-nix.md)
- `modules/flake/`: Flake-level modules for cross-host configuration.
  - [Flake Allocations](flake/allocations.md)
- `modules/home-manager/`: Contains Home-Manager-specific modules.
  - `Programs`
    - [list-ephemeral](home-manager/programs/list_ephemeral.md)
  - [DIY & Making](home-manager/diy.md)
  - [AI Editors & Assistants](home-manager/ai.md)
