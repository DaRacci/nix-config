# Desktop Module

The Desktop module provides a base configuration for desktop environments in the flake. It is a small aggregator typically imported by desktop and laptop hosts to ensure a common baseline for graphical environments.

## Purpose

This module bundles the common desktop-related services that should be present on all workstations. It does not expose its own options — it is purely an import aggregator for the following components:

| Component | Source | Documentation |
|---|---|---|
| Display Manager | `modules/nixos/shared/display-manager.nix` | [Display Manager](./display-manager.md) |
| Remote Access | `modules/nixos/shared/remote.nix` | [Remote Access](./remote.md) |

## Entry Point

- `modules/nixos/desktop/default.nix`

## Usage

This module must be manually imported in the host configuration.

## Operational Notes

- The same component set is also imported by the `laptop` module (`modules/nixos/laptop/default.nix`).
- To disable a specific sub-component, target that component's own `enable` option (e.g. `custom.display-manager.enable = false`).
