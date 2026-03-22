# Auto Upgrade

Schedules automatic NixOS upgrades from flake host outputs.

- **Entry point**: [auto-upgrade.nix](../../../../../modules/nixos/core/auto-upgrade.nix)

---

## Overview

This module configures `system.autoUpgrade` to rebuild host from `github:DaRacci/nix-config#<host>`. It also applies resource limits to `nixos-upgrade.service` so scheduled upgrades run with lower CPU and IO priority.

---

## Options

{{#include ../../../../generated/core-auto-upgrade-options.md}}

---

## Behaviour

When enabled, module configures:

- `system.autoUpgrade.dates = "04:00"`,
- `randomizedDelaySec = "45min"` to spread out upgrade times across hosts,
- flags `--refresh`, `--accept-flake-config`, and `--no-update-lock-file`,
- service resource controls for `nixos-upgrade.service`.

Auto-upgrade itself only turns on when flake has `self.rev`, meaning repository is in clean revisioned state.

---

## Usage Example

```nix
{ ... }: {
  core.auto-upgrade = {
    enable = true;
    hostName = "my-host";
  };
}
```

---

## Operational Notes

- Dirty working trees or non-revisioned evaluations leave `system.autoUpgrade.enable = false`.
- Module always points upgrades at GitHub flake source, not local checkout.
- Resource limits set `CPUWeight = 20`, `CPUQuota = 65%`, and `IOWeight = 20` on upgrade service.
