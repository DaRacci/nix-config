# Overlays Overview

## Purpose

Overlays allow us to extend or modify the standard `nixpkgs` collection. We use them to add our custom packages, apply patches, or override package versions.

## Entry Points

- `overlays/`: Directory containing individual overlay definitions.
- `overlays/default.nix`: The main entry point for the overlays. It composes additions (from `pkgs/` and external inputs) and modifications (overrides for upstream packages).

## Key Options/Knobs

Overlays themselves don't typically have "knobs," but they affect the available packages and their versions in the `pkgs` set.

## Notable Overrides

- **`kernelPackages.universal-pidff`**: Pinned to upstream commit [`595c65bb`](https://github.com/JacKeTUs/universal-pidff/commit/595c65bb23ad824cb6d8dedb1d74123f622de1cc) from `main`. Provides a newer force-feedback kernel module driver than the version bundled in the current nixpkgs release.
- **`discord`**: Overridden to enable OpenASAR and Vencord.
- **`hermes-agent`**: Local overlay that builds Hermes Agent from upstream source plus two applied patches:
  - [`overlays/patches/hermes-agent-pr-48637-lazy-deps.patch`](https://github.com/NousResearch/hermes-agent/pull/48637).
  - [`overlays/patches/hermes-agent-pr-87820-desktop-build-tsconfig.patch`](https://github.com/NousResearch/hermes-agent/pull/87820).
- **`hermes-desktop`** (`pkgs/default.nix`): Routes to `pkgs.hermes-agent.hermesDesktop`, exposing the patched Hermes Desktop package as a top-level `pkgs` entry for use in home-manager configs.

## Common Workflows

- **Adding an Overlay**: Create a new `.nix` file in the `overlays/` directory.
- **Applying an Overlay**: Overlays are typically applied in the `flake.nix` configuration for NixOS or Home-Manager.
