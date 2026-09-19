# SOPS — Shared SOPS and age decryption defaults

## Purpose

Provide a shared baseline for SOPS-managed secrets on every host: point sops-nix at the host's secrets file and teach age to use the host's provisioned SSH keys.

## Entry Point

- **Main file**: [sops.nix](../../../../../modules/nixos/core/sops.nix)

## Architecture / Services / Scope

When enabled, module:

- imports `sops-nix` (skipped when function argument `importExternals = false`),
- sets `sops.defaultSopsFile` to `core.sops.hostSecretsFile`,
- builds `sops.age.sshKeyPaths` from `core.openssh.hostPrivateKeyPath` first, then appends configured ed25519 OpenSSH host keys without duplicating the canonical path.

## Operational Notes / Assumptions

- Default age key path is `core.openssh.hostPrivateKeyPath`.
- Only ed25519 entries from `config.services.openssh.hostKeys` are appended to the age key paths.
- Secrets file defaults to `secrets.yaml` inside the host directory, overridable via `core.sops.hostSecretsFile`.
