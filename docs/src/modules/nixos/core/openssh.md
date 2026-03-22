# OpenSSH

Configures opinionated SSH server and client defaults.

- **Entry point**: [openssh.nix](../../../../../modules/nixos/core/openssh.nix)

---

## Overview

This module enables OpenSSH with ed25519-only host keys, disables password authentication, and generates known-host entries for all configured NixOS hosts in flake outputs.

It also wires SOPS-managed host private key into `sshd` and publishes matching public key under `/etc/ssh/ssh_host_ed25519_key.pub`.

---

## Options

{{#include ../../../../generated/core-openssh-options.md}}

---

## Behaviour

When enabled, module:

- enables `services.openssh`,
- disables socket activation (`startWhenNeeded = false`) to prevent mid-connection disruptions during system configuration switches,
- disables password authentication,
- sets `PermitRootLogin = "prohibit-password"`,
- sets `GatewayPorts = "clientspecified"`,
- configures `services.openssh.hostKeys` from `config.sops.secrets.SSH_PRIVATE_KEY.path`,
- publishes current host public key at `/etc/ssh/ssh_host_ed25519_key.pub`,
- enables `security.pam.sshAgentAuth`,
- adds current host public host key to `users.users.root.openssh.authorizedKeys.keyFiles`, and
- generates `programs.ssh.knownHosts` entries for every host in `outputs.nixosConfigurations`.

Client configuration also restricts host key algorithms and accepted public key types to `ssh-ed25519`.

---

## Usage Example

```nix
{ ... }: {
  core.openssh.enable = true;
}
```

---

## Operational Notes

- Module expects matching host public key file to exist in flake for each host.
- Current host gets `localhost` as extra known-host alias in generated SSH client config.
- Root authorization here uses host key material from flake, not per-user login keys.
- Private host key comes from SOPS secret `SSH_PRIVATE_KEY`, so `core.sops` integration usually pairs with this module.
- **Socket activation disabled**: By default, NixOS uses socket activation for SSH which spawns per-connection service instances (`sshd@...service`). When these instances are restarted during a configuration switch, it disconnects active SSH sessions. Disabling socket activation (`startWhenNeeded = false`) runs SSH as a traditional always-on service, preventing remote disconnection during `nixos-rebuild switch` over SSH.
