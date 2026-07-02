# WSL — Windows Subsystem for Linux integration and fixes

## Purpose

Make the NixOS host behave correctly inside WSL: default user, Windows interop, graphics library paths, `nix-ld`, and Start Menu launcher syncing.

## Entry Point

- **Main file**: [wsl.nix](../../../../../modules/nixos/core/wsl.nix)

## Architecture / Services / Scope

Base layer (always applied when enabled):

- allows passwordless login,
- installs `wslu`,
- enables `nix-ld` with a C toolchain library for VS Code Remote WSL compatibility,
- sets session variables for WSL graphics and library paths,
- enables `hardware.graphics` with the configured graphics packages and `libvdpau-va-gl`, and
- when NVIDIA graphics are present, appends CUDA and NVIDIA library paths.

If the `wsl` module exists in the option tree, module additionally:

- enables WSL with `core.wsl.user` as default user,
- enables Start Menu launchers and Windows driver usage,
- enables Windows interop and PATH appending,
- exposes `dirname`, `readlink`, and `uname` through `wsl.extraBin` for VS Code Remote WSL compatibility, and
- copies per-user Home Manager `applications` and `icons` into `/usr/share` during activation so launchers appear in the Windows Start Menu.

## Operational Notes / Assumptions

- `core.wsl.user` is required when WSL integration is enabled.
- Extra binaries `dirname`, `readlink`, and `uname` are exposed for VS Code Remote WSL compatibility.
- Behavior is conditional on the separate `wsl` module being available in `options`.
