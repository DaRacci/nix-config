# SOPS

Configures shared SOPS and age decryption defaults.

- **Entry point**: `modules/nixos/core/sops.nix`

______________________________________________________________________

## Overview

This module imports `sops-nix`, sets host default secrets file, derives age SSH key paths from persisted host SSH keys, and declares managed SSH private key secret for OpenSSH.

______________________________________________________________________

## Options

### `core.sops.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `config.core.enable` |

Enable automatic SOPS configuration.

### `core.sops.hostSecretsFile`

| | |
|---|---|
| Type | `path` |
| Default | `"${hostDirectory}/secrets.yaml"` |

Path to host-specific SOPS secrets file inside flake.

______________________________________________________________________

## Behaviour

When enabled, module:

- imports `inputs.sops-nix.nixosModules.sops` unless function argument `importExternals = false`,
- sets `sops.defaultSopsFile` to `core.sops.hostSecretsFile`,
- builds `sops.age.sshKeyPaths` from persisted host SSH key path first, then appends any configured ed25519 OpenSSH host keys, and
- declares `sops.secrets.SSH_PRIVATE_KEY` at `/etc/ssh/ssh_host_ed25519_key` with `sshd.service` restart hook.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.sops.hostSecretsFile = ./secrets.yaml;
}
```

______________________________________________________________________

## Operational Notes

- Default age key path includes `${config.host.persistence.root}/etc/ssh/ssh_host_ed25519_key`.
- Module filters `config.services.openssh.hostKeys` to ed25519 keys before adding them to `sops.age.sshKeyPaths`.
- `core.openssh` typically consumes `sops.secrets.SSH_PRIVATE_KEY` declared here.
