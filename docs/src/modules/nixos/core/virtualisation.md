# Virtualisation

Configures libvirt, VFIO passthrough, bridge networking, and guest isolation helpers.

- **Entry point**: `modules/nixos/core/virtualisation.nix`

______________________________________________________________________

## Overview

This module enables libvirt with QEMU, VFIO GPU passthrough, Looking Glass shared memory, bridge networking, custom OVMF firmware metadata, and libvirt hook helpers for selected guests.

It also generates helper scripts that change `AllowedCPUs` on host slices while selected guests run, detach and reattach passthrough GPUs for `-single` guests, and block host sleep while libvirt domains are active.

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

Users that receive `kvm` and `libvirtd` group membership for VM management.

### `core.virtualisation.isolatedGuests`

| | |
|---|---|
| Type | `list of string` |
| Default | `[ "win11" "win11-gaming" ]` |

Guest names that receive generated libvirt hook directories for CPU isolation helpers. Each guest also gets `-single` hook variants that add GPU detach and attach helpers.

### `core.virtualisation.bridgeInterface`

| | |
|---|---|
| Type | `string` |
| Default | `"br0"` |

Bridge interface exposed to libvirt guests.

### `core.virtualisation.externalInterface`

| | |
|---|---|
| Type | `string` |
| Default | `"eth0"` |

Physical interface attached to `core.virtualisation.bridgeInterface`.

### `core.virtualisation.cpuCores`

| | |
|---|---|
| Type | `int >= 4` |
| Default | `24` |

Total CPU core or thread count used by isolation helpers.

### `core.virtualisation.gpu.video`

| | |
|---|---|
| Type | `string` |
| Default | `"10de:1b06"` |

PCI ID for passthrough GPU video device.

### `core.virtualisation.gpu.audio`

| | |
|---|---|
| Type | `string` |
| Default | `"10de:1bef"` |

PCI ID for passthrough GPU audio device.

______________________________________________________________________

## Behaviour

When enabled, module:

- imports external virtualisation helpers from `crtified.modules.virtualisation.nix` and `../desktop/vfio.nix`,
- enables `virtualisation.libvirtd`, Spice USB redirection, and `services.spice-autorandr`,
- enables VFIO with `IOMMUType = "amd"`, `disableEFIfb = true`, and configured GPU devices,
- configures Looking Glass shared memory file `looking-glass` owned by `racci:qemu-libvirtd`,
- adds `virt-manager`, `virtiofsd`, `virtio-win`, and `win-spice` to system packages,
- sets `LIBVIRT_DEFAULT_URI = qemu:///system`,
- creates bridge networking with DHCP on `bridgeInterface` and `externalInterface` enslaved into bridge,
- adds `kvmfr` kernel module package and modprobe config `static_size_mb=128`, and
- installs udev rule for `/dev/kvmfr` access.

Module also persists libvirt and swtpm state under `host.persistence.directories`.

______________________________________________________________________

## Isolation and Hook Helpers

For each guest in `core.virtualisation.isolatedGuests`, module creates libvirt hook entries that:

- restrict host `user.slice`, `system.slice`, and `init.scope` CPU sets during guest startup,
- restore full CPU set when guest stops,
- for `<guest>-single`, detach GPU and stop display-related services before launch, and
- reattach GPU, reload drivers, restart saved services, and rebind VT consoles after shutdown.

It also creates `libvirt-nosleep@<guest>` service that uses `systemd-inhibit` to block sleep while guest is running.

______________________________________________________________________

## Firmware and Persistence

Module extends libvirt startup to populate `/run/libvirt/nix-ovmf` with secure-boot and Microsoft-enrolled OVMF firmware files, then publishes matching firmware JSON metadata under `/var/lib/qemu/firmware`.

Persisted paths include:

- `/var/lib/libvirt/qemu`
- `/var/lib/libvirt/images`
- `/var/lib/libvirt/swtpm`
- `/var/lib/libvirt/secrets`
- `/var/lib/swtpm-localca`

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.virtualisation = {
    enable = true;
    vmUsers = [ "racci" ];
    isolatedGuests = [ "win11-gaming" ];
    bridgeInterface = "br0";
    externalInterface = "enp6s0";
    cpuCores = 24;

    gpu = {
      video = "10de:1b06";
      audio = "10de:1bef";
    };
  };
}
```

______________________________________________________________________

## Operational Notes

- `core.virtualisation.cpuCores` is validated by both option type and assertion, so values below `4` fail evaluation.
- `vmUsers` is opt-in. Only listed users receive `kvm` and `libvirtd` access.
- Hook generation assumes guest naming convention where `<name>-single` means single-GPU passthrough workflow.
