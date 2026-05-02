# Nix

Defines shared Nix daemon, cache, and registry defaults.

- **Entry point**: `modules/nixos/core/nix.nix`

______________________________________________________________________

## Overview

This module establishes global Nix configuration for hosts in this flake. It sets overlays, `system.stateVersion`, trusted users, experimental features, binary caches, garbage collection, and registry-derived `nixPath`.

It also provisions cache push secret and `attic-watch-store` service for automatic uploads to remote Attic cache.

______________________________________________________________________

## Options

This module does not define `core.*` options. It applies shared baseline configuration directly.

______________________________________________________________________

## Behaviour

Module configures:

- overlays from `inputs.angrr` and `inputs.nix4vscode`,
- `system.stateVersion` from `state.version` file in flake root,
- trusted Nix users `root` and `@wheel`,
- `nix.settings.auto-optimise-store = mkForce true`,
- experimental features `nix-command`, `flakes`, and `pipe-operator`,
- substituters, trusted substituters, and trusted public keys for `cache.nixos.org`, `nix-community`, and `cache.racci.dev`,
- daily automatic Nix GC, and
- `nix.nixPath` derived from `config.nix.registry`.

It also enables `services.angrr` to retain recent system profiles and creates `systemd.services.attic-watch-store` that waits for `network-online.target`, restarts on failure, logs into Attic with SOPS-managed `CACHE_PUSH_KEY`, and watches store for uploads.

______________________________________________________________________

## Operational Notes

- Because module has no enable flag, this is always active and applied to all hosts.
- `attic-watch-store` depends on `sops.secrets.CACHE_PUSH_KEY` from `hosts/secrets.yaml`.
- `services.angrr` keeps system profiles for 14 days, latest 3 generations, current system, and booted system.
