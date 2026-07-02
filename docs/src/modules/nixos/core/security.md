# Security — Shared host security defaults

## Purpose

Enable baseline host security: `sudo-rs`, TPM2 support, Polkit, kernel protection flags, and open-file limits for users.

## Entry Point

- **Main file**: [security.nix](../../../../../modules/nixos/core/security.nix)

## Architecture / Services / Scope

When enabled, module:

- enables `sudo-rs` in place of sudo, restricted to the wheel group,
- enables TPM2 and Polkit,
- enables kernel image protection while leaving `lockKernelModules` off,
- sets PAM and user systemd service open-file limits from `core.security.userLimit`, and
- raises `fs.file-max` to a multiple of `userLimit`.

## Operational Notes / Assumptions

- Module leaves `security.lockKernelModules = false` even while enabling other hardening defaults.
- `userLimit` affects both PAM sessions and user systemd services, keeping file descriptor limits aligned.
