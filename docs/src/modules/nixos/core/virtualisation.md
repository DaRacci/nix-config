# Virtualisation

Configures libvirt, VFIO passthrough, and guest isolation helpers for desktop virtual machines.

- **Entry point**: `modules/nixos/core/virtualisation.nix`

______________________________________________________________________

## Overview

This module enables libvirt with QEMU, VFIO GPU passthrough, Looking Glass shared memory, bridge networking, and libvirt hook helpers for selected guests.

It also generates helper scripts that call `systemctl set-property --runtime -- ... AllowedCPUs=...` to isolate host workloads while selected guests run.

______________________________________________________________________

## Options

### `core.virtualisation.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Master switch for virtualisation support.

### `core.virtualisation.vmUsers`

| | |
|---|---|
| Type | `list of string` |
| Default | `[]` |

Explicit allowlist of users that receive `kvm` and `libvirtd` group membership for VM management. No wildcard default is applied.

### `core.virtualisation.cpuCores`

| | |
|---|---|
| Type | `int >= 4` |
| Default | `24` |

Total CPU core or thread count used by isolation helpers.

This value must be at least `4`. Module asserts `core.virtualisation.cpuCores >= 4` before generating `AllowedCPUs` ranges so invalid values cannot produce inverted ranges or emit `systemctl set-property` calls with bad CPU sets.

______________________________________________________________________

## Operational Notes

- `core.virtualisation.vmUsers` is opt-in. Only listed users receive `kvm` and `libvirtd` access for VM management.
- `core.virtualisation.cpuCores` is validated twice: option type requires `>= 4`, and module assertion fails early with message that references `core.virtualisation.cpuCores`.
- Isolation helper scripts derive `AllowedCPUs` ranges from `core.virtualisation.cpuCores`, so low values like `1` to `3` are rejected during evaluation.
