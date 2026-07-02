# Auto Upgrade

Schedules automatic NixOS upgrades from flake host outputs.

## Purpose

Keep hosts current by rebuilding them from the flake on a schedule, with randomized start times to spread load across hosts and resource limits so upgrades do not starve interactive workloads.

## Entry Point

- **Main file**: [auto-upgrade.nix](../../../../../modules/nixos/core/auto-upgrade.nix)

## Architecture / Services / Scope

When enabled, the module configures `system.autoUpgrade` to rebuild the host from `github:DaRacci/nix-config#<host>`, using the `--refresh`, `--accept-flake-config`, and `--no-update-lock-file` flags, and applies CPU and IO resource limits to `nixos-upgrade.service`.

## Operational Notes / Assumptions

- Auto-upgrade only turns on when the flake has a revision (`self.rev`), meaning the repository is in a clean, revisioned state. Dirty working trees or non-revisioned evaluations leave `system.autoUpgrade.enable = false`.
- Upgrades always target the GitHub flake source, not the local checkout.
