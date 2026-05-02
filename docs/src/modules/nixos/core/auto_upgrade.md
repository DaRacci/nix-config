# Auto Upgrade

Schedules automatic NixOS upgrades from flake host outputs.

- **Entry point**: `modules/nixos/core/auto-upgrade.nix`

______________________________________________________________________

## Overview

This module configures `system.autoUpgrade` to rebuild host from `github:DaRacci/nix-config#<host>`. It also applies resource limits to `nixos-upgrade.service` so scheduled upgrades run with lower CPU and IO priority.

______________________________________________________________________

## Options

### `core.auto-upgrade.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `true` |

Enable automatic upgrade configuration.

### `core.auto-upgrade.hostName`

| | |
|---|---|
| Type | `string` |
| Default | `config.networking.hostName` |

Host output name used in flake reference `github:DaRacci/nix-config#<hostName>`.

______________________________________________________________________

## Behaviour

When enabled, module configures:

- `system.autoUpgrade.dates = "04:00"`,
- `randomizedDelaySec = "45min"` to spread out upgrade times across hosts,
- flags `--refresh`, `--accept-flake-config`, and `--no-update-lock-file`,
- service resource controls for `nixos-upgrade.service`.

Auto-upgrade itself only turns on when flake has `self.rev`, meaning repository is in clean revisioned state.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.auto-upgrade = {
    enable = true;
    hostName = "my-host";
  };
}
```

______________________________________________________________________

## Operational Notes

- Dirty working trees or non-revisioned evaluations leave `system.autoUpgrade.enable = false`.
- Module always points upgrades at GitHub flake source, not local checkout.
- Resource limits set `CPUWeight = 20`, `CPUQuota = 65%`, and `IOWeight = 20` on upgrade service.
