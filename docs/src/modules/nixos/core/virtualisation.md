# Virtualisation — libvirt, VFIO passthrough, bridge networking, and guest isolation helpers

## Purpose

Enable libvirt/QEMU virtualization with VFIO GPU passthrough, Looking Glass shared memory, bridge networking, custom OVMF firmware metadata, and per-guest isolation helpers that reserve host CPUs, detach GPUs, and block host sleep while guests run.

## Entry Point

- **Main file**: [virtualisation.nix](../../../../../modules/nixos/core/virtualisation.nix)

## Architecture / Services / Scope

When enabled, module:

- imports external virtualisation helpers from `crtified.modules.virtualisation.nix` and `../desktop/vfio.nix`,
- enables `virtualisation.libvirtd`, Spice USB redirection, and `services.spice-autorandr`,
- enables VFIO with AMD IOMMU, `disableEFIfb`, and the configured GPU devices,
- configures Looking Glass shared memory file owned by the libvirt group,
- adds `virt-manager`, `virtiofsd`, `virtio-win`, and `win-spice` to system packages,
- sets `LIBVIRT_DEFAULT_URI` to `qemu:///system`,
- creates bridge networking with DHCP on `bridgeInterface` and `externalInterface` enslaved into the bridge,
- adds `kvmfr` kernel module package and modprobe config,
- installs udev rule for `/dev/kvmfr` access, and
- persists libvirt and swtpm state under `host.persistence.directories`.

### Isolation and Hook Helpers

For each guest in `core.virtualisation.isolatedGuests`, module creates libvirt hook entries that:

- restrict host `user.slice`, `system.slice`, and `init.scope` CPU sets during guest startup,
- restore full CPU set when guest stops,
- for `<guest>-single`, detach GPU and stop display-related services before launch, and
- reattach GPU, reload drivers, restart saved services, and rebind VT consoles after shutdown.

It also creates `libvirt-nosleep@<guest>` service that uses `systemd-inhibit` to block sleep while guest is running.

### Firmware and Persistence

Module extends libvirt startup to populate `/run/libvirt/nix-ovmf` with secure-boot and Microsoft-enrolled OVMF firmware files, then publishes matching firmware JSON metadata under `/var/lib/qemu/firmware`.

Persisted paths include:

- `/var/lib/libvirt/qemu`
- `/var/lib/libvirt/images`
- `/var/lib/libvirt/swtpm`
- `/var/lib/libvirt/secrets`
- `/var/lib/swtpm-localca`

## Operational Notes / Assumptions

- `core.virtualisation.cpuCores` is validated by both option type and assertion, so values below `4` fail evaluation.
- `vmUsers` is opt-in. Only listed users receive `kvm` and `libvirtd` access.
- Hook generation assumes guest naming convention where `<name>-single` means single-GPU passthrough workflow.
