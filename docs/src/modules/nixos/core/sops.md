# SOPS — Shared SOPS and age decryption defaults

## Purpose

Provide a shared baseline for SOPS-managed secrets on every host: point sops-nix at the host's secrets file, teach age to use the host's SSH keys, and keep the OpenSSH host private key in sync through a managed secret.

## Entry Point

- **Main file**: [sops.nix](../../../../../modules/nixos/core/sops.nix)

## Architecture / Services / Scope

When enabled, module:

- imports `sops-nix` (skipped when function argument `importExternals = false`),
- sets `sops.defaultSopsFile` to `core.sops.hostSecretsFile`,
- builds `sops.age.sshKeyPaths` from the persisted host SSH key path first, then appends configured ed25519 OpenSSH host keys, and
- declares `sops.secrets.SSH_PRIVATE_KEY` at the OpenSSH host key path with an `sshd.service` restart hook.

## Secrets

- `SSH_PRIVATE_KEY` is declared here and typically consumed by `core.openssh`.
- Age keys are derived from the host's persisted ed25519 SSH keys; matching public keys must exist so secrets can be encrypted per host.

## Operational Notes / Assumptions

- Default age key path includes the persisted `/etc/ssh/ssh_host_ed25519_key`.
- Only ed25519 entries from `config.services.openssh.hostKeys` are appended to the age key paths.
- Secrets file defaults to `secrets.yaml` inside the host directory, overridable via `core.sops.hostSecretsFile`.
