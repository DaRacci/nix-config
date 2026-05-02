# WSL

Adds Windows Subsystem for Linux specific integration and fixes.

- **Entry point**: `modules/nixos/core/wsl.nix`

______________________________________________________________________

## Overview

This module configures WSL-focused defaults such as default user, Windows interop, graphics library paths, `nix-ld`, and Start Menu launcher syncing.

______________________________________________________________________

## Options

### `core.wsl.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Enable WSL-specific configuration.

### `core.wsl.user`

| | |
|---|---|
| Type | `string` |
| Default | none |

Default user used for WSL integration.

______________________________________________________________________

## Behaviour

When enabled, module:

- sets `users.allowNoPasswordLogin = true`,
- installs `pkgs.wslu`,
- enables `programs.nix-ld` with C toolchain library for Remote WSL compatibility,
- sets session variables for WSL graphics and library paths,
- enables `hardware.graphics` and adds `config.hardware.graphics.package`, `config.hardware.graphics.package32`, and `pkgs.libvdpau-va-gl`, and
- when NVIDIA graphics are present, appends CUDA and NVIDIA library paths.

If `wsl` module exists in option tree, module also:

- enables `wsl.enable`,
- sets `wsl.defaultUser = core.wsl.user`,
- enables Start Menu launchers and Windows driver usage,
- enables Windows interop and PATH appending,
- exposes `dirname`, `readlink`, and `uname` through `wsl.extraBin` for VS Code Remote WSL compatibility, and
- copies per-user Home Manager `applications` and `icons` into `/usr/share` during activation so launchers appear in Windows Start Menu.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.wsl = {
    enable = true;
    user = "racci";
  };
}
```

______________________________________________________________________

## Operational Notes

- `core.wsl.user` is required when WSL integration is enabled.
- Extra binaries `dirname`, `readlink`, and `uname` are exposed for VS Code Remote WSL compatibility.
- Some behavior is conditional on separate WSL module being available in `options`.
