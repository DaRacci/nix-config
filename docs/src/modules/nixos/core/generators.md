# Generators

Configures image and container generator support for shared NixOS hosts.

- **Entry point**: [generators.nix](../../../../../modules/nixos/core/generators.nix)

---

## Overview

This module imports `nixos-generators` formats and exposes `core.generators` options for generator-specific setup.

Current focus is Proxmox LXC image generation. When enabled for virtual hosts, module adds activation logic that prompts for SSH host private key on first boot, validates it with `ssh-keygen`, and stores it under `/persist/etc/ssh/ssh_host_ed25519_key` so later secret management can install it into `/etc/ssh`.

---

## Options

{{#include ../../../../generated/core-generators-options.md}}

---

## Assertions and Behaviour

When `core.generators.proxmoxLXC.enable = true`, module asserts that image contains `/etc/ssh/ssh_host_ed25519_key.pub`.

If activation runs without controlling terminal, prompt is skipped and activation exits cleanly. If terminal exists, module loops until pasted private key:

- contains valid OpenSSH private key block,
- passes `ssh-keygen -y`, and
- matches public key already present at `/etc/ssh/ssh_host_ed25519_key.pub`.

---

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

---

## Operational Notes

- `nixos-generators` formats are imported unconditionally by module, but runtime configuration only applies when `core.generators.enable` is on.
- Proxmox LXC flow is designed for images where public host key is baked into image but private key must be supplied interactively after boot.
- Stored private key lives in `/persist`, so persistence and later secret deployment must be configured for target host.
