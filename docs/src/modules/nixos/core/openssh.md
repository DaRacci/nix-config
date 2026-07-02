# OpenSSH

Configures opinionated SSH server and client defaults.

## Purpose

Provide a hardened, consistent SSH experience across hosts: ed25519-only host keys, no password authentication, automatically generated known-host entries, and PAM ssh-agent authentication.

## Entry Point

- **Main file**: [openssh.nix](../../../../../modules/nixos/core/openssh.nix)

## Architecture / Services / Scope

When enabled, the module:

- enables `services.openssh` with socket activation disabled so SSH runs as a traditional always-on service (avoiding disconnects during `nixos-rebuild switch` over SSH),
- disables password authentication and sets `PermitRootLogin = "prohibit-password"`,
- configures the ed25519 host key from the SOPS-managed private key path and publishes the matching public key at `/etc/ssh/ssh_host_ed25519_key.pub`,
- enables `security.pam.sshAgentAuth`,
- adds the current host's public host key to root's authorized keys, and
- generates `programs.ssh.knownHosts` entries for every host in `outputs.nixosConfigurations`.

Client configuration restricts host key algorithms and accepted public key types to `ssh-ed25519`.

## Secrets

The module consumes the SOPS-managed `SSH_PRIVATE_KEY` secret (declared by `core.sops`) as the sshd host key.

## Operational Notes / Assumptions

- Module expects a matching host public key file to exist in the flake for each host.
- The current host gets `localhost` as an extra known-host alias in the generated SSH client config.
- Root authorization uses host key material from the flake, not per-user login keys.
- `core.sops` integration usually pairs with this module, since the private host key comes from SOPS.
- Socket activation is disabled (`startWhenNeeded = false`): the default NixOS setup spawns per-connection `sshd@...service` instances, and restarting them during a configuration switch disconnects active SSH sessions. An always-on service prevents remote disconnection during `nixos-rebuild switch`.
