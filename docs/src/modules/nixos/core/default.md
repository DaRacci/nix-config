# Core Module

Documents shared NixOS core modules used across hosts.

## Purpose

`modules/nixos/core/` contains reusable host-level defaults and feature modules.

It also defines top-level baseline options under `core.*` that control this shared behavior for most hosts.

## Options

{{#include ../../../../generated/core-options.md}}

## Baseline Behaviour

When `core.enable` is true, module applies shared defaults from `modules/nixos/core/default.nix`:

- sets `services.dbus.implementation = "broker"`,
- enables PipeWire audio stack and disables PulseAudio when `core.audio.enable` is on,
- enables Bluetooth stack, Blueman, and persisted Bluetooth state when `core.bluetooth.enable` is on,
- enables NetworkManager and adds `network` to shared default groups when `core.network.enable` is on, and
- on non-headless hosts, adds `video` and `i2c` groups and enables `dleyna`, `gnome-keyring`, `udisks2`, `colord`, `xserver.updateDbusEnvironment`, and `polkit`.

Audio baseline also enables `security.rtkit`, adds `audio`, `pipewire`, and `rtkit` groups, installs udev rules for `rtc0` and `hpet`, and sets PAM limits for realtime audio workloads.

Bluetooth baseline unblocks rfkill during activation and persists `/var/lib/bluetooth`.

## Key Pages

- [Activation](activation.md)
- [Auto Upgrade](auto_upgrade.md)
- [Containers](containers.md)
- [Display Manager](display_manager.md)
- [Gaming](gaming.md)
- [Generators](generators.md)
- [Default Groups](default_groups.md)
- [Locale](locale.md)
- [Nix](nix.md)
- [OpenSSH](openssh.md)
- [Printing](printing.md)
- [Remote Access](remote.md)
- [Security](security.md)
- [SOPS](sops.md)
- [Stylix](stylix.md)
- [Virtualisation](virtualisation.md)
- [WSL](wsl.md)

## Usage Example

```nix
{ ... }: {
  core = {
    enable = true;
    audio.enable = true;
    bluetooth.enable = true;
    network.enable = true;
  };
}
```

## Notes

These modules are imported through `modules/nixos/core/default.nix`. Most feature pages document their own `core.<name>` option namespaces, while some baseline modules such as [Nix](nix.md) apply unconditionally once imported.
