# Generators

Configures image and container generator support for shared NixOS hosts.

- **Entry point**: `modules/nixos/core/generators.nix`

______________________________________________________________________

## Overview

This module imports `nixos-generators` formats and exposes `core.generators` options for generator-specific setup.

Current focus is Proxmox LXC image generation. When enabled for virtual hosts, module adds activation logic that prompts for SSH host private key on first boot, validates it with `ssh-keygen`, and stores it under `/persist/etc/ssh/ssh_host_ed25519_key` so later secret management can install it into `/etc/ssh`.

______________________________________________________________________

## Options

### `core.generators.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `config.core.enable` |

Enable shared generator configuration and import generator formats from `nixos-generators`.

### `core.generators.proxmoxLXC.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `cfg.enable && config.host.device.isVirtual` |

Enable Proxmox LXC generator integration. Adds first-boot SSH private key prompt and Proxmox LXC format configuration.

### `core.generators.proxmoxLXC.sedPath`

| | |
|---|---|
| Type | `path` |
| Default | `getExe' pkgs.busybox "sed"` |

Path to `sed` binary used to extract pasted OpenSSH private key block from terminal input.

### `core.generators.proxmoxLXC.sshKeygenPath`

| | |
|---|---|
| Type | `path` |
| Default | `getExe' pkgs.openssh "ssh-keygen"` |

Path to `ssh-keygen` binary used to validate pasted private key and derive matching public key.

### `core.generators.proxmoxLXC.clearPath`

| | |
|---|---|
| Type | `path` |
| Default | `getExe' pkgs.busybox "clear"` |

Path to `clear` binary used between failed interactive prompt attempts.

______________________________________________________________________

## Assertions and Behaviour

When `core.generators.proxmoxLXC.enable = true`, module asserts that image contains `/etc/ssh/ssh_host_ed25519_key.pub`.

If activation runs without controlling terminal, prompt is skipped and activation exits cleanly. If terminal exists, module loops until pasted private key:

- contains valid OpenSSH private key block,
- passes `ssh-keygen -y`, and
- matches public key already present at `/etc/ssh/ssh_host_ed25519_key.pub`.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.generators = {
    enable = true;

    proxmoxLXC = {
      enable = true;
    };
  };
}
```

______________________________________________________________________

## Operational Notes

- `nixos-generators` formats are imported unconditionally by module, but runtime configuration only applies when `core.generators.enable` is on.
- Proxmox LXC flow is designed for images where public host key is baked into image but private key must be supplied interactively after boot.
- Stored private key lives in `/persist`, so persistence and later secret deployment must be configured for target host.
