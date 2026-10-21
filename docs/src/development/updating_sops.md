# Updating SOPS Rules

`update-sops` first regenerates managed `sops-keys.nix`, then regenerates `.sops.yaml` from repository layout. Host and home entries are sorted by name for stable output. Run it after adding, removing, or rotating a host key or home user.

## Host Discovery

A host is discovered only when this file exists:

```text
hosts/{device-type}/{hostname}/ssh_host_ed25519_key.pub
```

The script converts each OpenSSH public key with `ssh-to-age` and creates rules for:

- `hosts/secrets.yaml` — every discovered host
- `hosts/server/secrets.yaml` — every discovered server
- `hosts/{device-type}/{hostname}/` — each discovered host directory

Host-specific rules also cover nested SOPS files under that host directory.

## Managed Key Map

`update-sops` writes `sops-keys.nix` as a readable inventory of discovered recipients:

```nix
{
  deployer = "age1gmc8dd4mj5q0zncy5gq4lccjlq9v84t8cqnlananmxt8g0jezv6szawll8";
  homes = {
    racci = "...";
  };
  hosts = {
    server = {
      nixauth = "...";
    };
  };
}
```

Host recipients come from `ssh_host_ed25519_key.pub`. Home recipients come from `home/{username}/id_ed25519.pub`. The current user's name comes from `whoami`; that user's home recipient is used as the personal recipient in every generated SOPS rule. The current user must have a home public key file.

Every directory under `home/`, except `home/shared/`, gets a rule for:

```text
home/{username}/secrets.yaml
```

Home directories without `id_ed25519.pub` still get SOPS rules, but do not get an entry in `sops-keys.nix`.

## Common Recipients

Every generated rule starts with two always-present recipients, in this order:

1. current user's `home/{username}/id_ed25519.pub` converted with `ssh-to-age` — personal age key
1. `sops-keys.nix` `deployer` value — automated deployer age key

The updater defines this policy in `get-always-present-age-keys`. Host-specific rules append that host's age recipient. Global host rules append all applicable host recipients in the same stable order used by `sops-keys.nix`.

## Usage

Regenerate rules:

```bash
update-sops
```

Check for drift without writing:

```bash
update-sops --check
```

By default, updater changes only `sops-keys.nix` and `.sops.yaml`. To also update recipient metadata in every encrypted SOPS file under `hosts/` and `home/`, opt in explicitly:

```bash
update-sops --update-secrets
```

This runs `sops updatekeys --yes` for each file reported as encrypted by `sops filestatus`, including non-YAML formats. It can re-encrypt file metadata and requires an available SOPS decryption identity. `--update-secrets` cannot be combined with `--check`.
