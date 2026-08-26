# Generators

Configures image and container generator support for shared NixOS hosts.

## Purpose

Expose `nixos-generators` image formats through a `core.generators` option namespace and provide generator-specific setup, currently focused on Proxmox LXC images.

## Entry Point

- **Main file**: [generators.nix](../../../../../modules/nixos/core/generators.nix)

### Options

{{#include ../../../../generated/core-generators-options.md}}

## Architecture / Services / Scope

The module imports `nixos-generators` formats unconditionally, but runtime configuration only applies when `core.generators.enable` is on.

When `core.generators.proxmoxLXC.enable = true`, the module:

- asserts the image contains the SSH host public key at `/etc/ssh/ssh_host_ed25519_key.pub`, and
- adds activation logic that prompts for the SSH host private key on first boot when a controlling terminal is available.

The interactive prompt loops until the pasted key contains a valid OpenSSH private key block, passes `ssh-keygen -y`, and matches the public key already present in the image. The accepted key is stored under `/persist/etc/ssh/ssh_host_ed25519_key` so later secret management can install it into `/etc/ssh`.

## Operational Notes / Assumptions

- The Proxmox LXC flow is designed for images where the public host key is baked in but the private key must be supplied interactively after boot.
- If activation runs without a controlling terminal, the prompt is skipped and activation exits cleanly.
- The stored private key lives in `/persist`, so persistence and later secret deployment must be configured for the target host.
