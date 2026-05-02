# OpenSSH

Configures opinionated SSH server and client defaults.

- **Entry point**: `modules/nixos/core/openssh.nix`

______________________________________________________________________

## Overview

This module enables OpenSSH with ed25519-only host keys, disables password authentication, and generates known-host entries for all configured NixOS hosts in flake outputs.

It also wires SOPS-managed host private key into `sshd` and publishes matching public key under `/etc/ssh/ssh_host_ed25519_key.pub`.

______________________________________________________________________

## Options

### `core.openssh.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `true` |

Enable opinionated OpenSSH server and client configuration.

______________________________________________________________________

## Behaviour

When enabled, module:

- enables `services.openssh`,
- disables password authentication,
- sets `PermitRootLogin = "prohibit-password"`,
- sets `GatewayPorts = "clientspecified"`,
- configures `services.openssh.hostKeys` from `config.sops.secrets.SSH_PRIVATE_KEY.path`,
- publishes current host public key at `/etc/ssh/ssh_host_ed25519_key.pub`,
- enables `security.pam.sshAgentAuth`,
- adds current host public host key to `users.users.root.openssh.authorizedKeys.keyFiles`, and
- generates `programs.ssh.knownHosts` entries for every host in `outputs.nixosConfigurations`.

Client configuration also restricts host key algorithms and accepted public key types to `ssh-ed25519`.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.openssh.enable = true;
}
```

______________________________________________________________________

## Operational Notes

- Module expects matching host public key file to exist in flake for each host.
- Current host gets `localhost` as extra known-host alias in generated SSH client config.
- Root authorization here uses host key material from flake, not per-user login keys.
- Private host key comes from SOPS secret `SSH_PRIVATE_KEY`, so `core.sops` integration usually pairs with this module.
