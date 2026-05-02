# Gaming

Enables gaming, VR, and Steam-focused desktop features.

- **Entry point**: `modules/nixos/core/gaming.nix`

______________________________________________________________________

## Overview

This module configures desktop gaming stack around Steam, 32-bit graphics support, Android ADB tools, and WiVRn streaming. It also adds firewall rules, udev rules for common gaming devices, and optional Decky Loader lifecycle integration.

______________________________________________________________________

## Options

### `core.gaming.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Enable gaming feature set.

______________________________________________________________________

## Behaviour

When enabled, module:

- adds `adbusers` to `core.defaultGroups`,
- enables `hardware.steam-hardware`,
- enables 32-bit graphics support,
- installs `pkgs.android-tools`,
- enables Steam with Steam Deck style launch arguments,
- enables `programs.steam.extest`,
- adds `pkgs.xwayland-run` and `pkgs.xwininfo` as Steam extra packages,
- adds `pkgs.proton-ge-bin` as compatibility package,
- opens Steam Remote Play and local transfer firewall rules,
- enables `services.wivrn` with `autoStart`, `highPriority`, `steam.importOXRRuntimes`, firewall access, and JSON config, and
- installs udev rules for PlayStation controller, Oculus Quest, and tty ACM devices.

It also overlays `gamescope-session` to use 4K resolution and wider refresh limits, and opens firewall ports UDP `41492`, `9943`, `9944` plus TCP `8082`, `9943`, `9944`, and `24070`.

______________________________________________________________________

## Decky Loader Integration

If `config.jovian.decky-loader.enable` is true, module additionally:

- prevents `decky-loader.service` from auto-starting at boot,
- adds Polkit rule so active local user can start and stop `decky-loader.service`, and
- when Home Manager is present, installs user service that polls Steam PID file, starts Decky Loader once Steam is running, and stops it after Steam exits.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.gaming.enable = true;
}
```

______________________________________________________________________

## Operational Notes

- Module assumes desktop-class host with graphics stack and Steam support.
- WiVRn config uses NVENC H.265 encoder entries and enables `pkgs.wayvr` as application.
- Some extra behavior only appears when related modules already exist, such as Jovian Decky Loader and Home Manager.
