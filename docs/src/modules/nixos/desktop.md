# Desktop Module

The Desktop module provides a base configuration for desktop environments in the flake. It is a small aggregator typically imported by desktop hosts to ensure a common baseline for graphical environments.

## Purpose

The primary purpose of this module is to bundle common desktop-related services and configurations that should be present on all workstations, such as display managers, remote access tools, and hardware features like RGB lighting and VFIO passthrough.

## Entry Point

- `modules/nixos/desktop/default.nix`

## Special Options and Behaviors

This module does not expose its own options. Instead, it serves as a central point for importing desktop-specific and shared components:

- **RGB Lighting**: Configured via `./rgb.nix` — OpenRGB-based hardware lighting control.
- **VFIO Passthrough**: Configured via `./vfio.nix` — GPU/device passthrough for virtual machines.
- **Display Manager**: Configured via `../shared/features/display-manager.nix`.
- **Remote Access**: Configured via `../shared/features/remote.nix`.

Additionally, `./virtual-machine.nix` provides VM guest configuration and is available for desktop hosts to import separately.

## Example Usage

This module is a base component for desktop hosts. It must be manually imported in the host's configuration.

```nix
# hosts/desktop/my-workstation/default.nix
{
  imports = [
    ../../../modules/nixos/desktop/default.nix
  ];
}
```

## Operational Notes

- This module ensures that all desktop hosts have a consistent baseline for graphical interfaces and remote management.
- If you need to disable a specific component imported by this module, you may need to use `lib.mkForce` or target the specific component's enable option if available.