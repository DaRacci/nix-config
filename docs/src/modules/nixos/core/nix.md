# Nix

Defines shared Nix daemon, cache, and registry defaults.

## Purpose

Establish global Nix configuration for every host in the flake: overlays, state version, trusted users, experimental features, binary caches, garbage collection, registry-derived `nixPath`, plus automatic uploads to the remote Attic cache.

## Entry Point

- **Main file**: [nix.nix](../../../../../modules/nixos/core/nix.nix)

## Architecture / Services / Scope

The module applies shared baseline configuration directly (no `core.*` options). It:

- installs the `nix4vscode` overlay,
- sets `system.stateVersion` from the `state.version` file at the flake root,
- configures trusted users, automatic store optimisation, experimental features, substituters and trusted public keys for the project's binary caches, daily automatic GC, and a `nixPath` derived from `config.nix.registry`.

It also:

- enables `services.angrr` to retain recent system profiles, and
- creates `systemd.services.attic-watch-store`, which waits for `network-online.target`, restarts on failure, logs into Attic using a SOPS-managed cache push key, and watches the store for uploads.

## Secrets

The module declares the SOPS secret `CACHE_PUSH_KEY` (from `hosts/secrets.yaml`) and restarts `attic-watch-store.service` when it changes. This key authenticates automatic uploads to the remote Attic cache.

## Operational Notes / Assumptions

- Because the module has no enable flag, it is always active and applied to all hosts.
- `attic-watch-store` depends on `sops.secrets.CACHE_PUSH_KEY` from `hosts/secrets.yaml`.
- `services.angrr` keeps a bounded set of recent system profile generations.
