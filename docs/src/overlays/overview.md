# Overlays Overview

## Purpose

Overlays allow us to extend or modify the standard `nixpkgs` collection.
We use them to add our custom packages, apply patches, or override package versions.

## Architecture / Services / Scope

### Entry Points

- `overlays/`: Directory containing individual overlay definitions.
- `overlays/default.nix`: The main entry point for the overlays.
  It composes additions (from `pkgs/` and external inputs) and modifications (overrides for upstream packages).

## Operational Notes / Assumptions

### Key Options/Knobs

Overlays themselves don't typically have "knobs," but they affect the available packages and their versions in the `pkgs` set.

### Notable Overrides

- **`kernelPackages.universal-pidff`**: Pinned to upstream commit
  [`595c65bb`](https://github.com/JacKeTUs/universal-pidff/commit/595c65bb23ad824cb6d8dedb1d74123f622de1cc) from `main`.
  Provides a newer force-feedback kernel module driver than the version bundled in the current nixpkgs release.
- **`discord`**: Overridden to enable OpenASAR, with Vencord disabled until
  [`nixpkgs#584169`](https://github.com/NixOS/nixpkgs/pull/584169) lands.
- **`fastembed-hermes`**: Overrides `fastembed` from `hermes-agent.packages.<system>.default.python.pkgs` to strip Python deps already bundled
  in the Hermes sealed uv2nix environment (e.g. `snowballstemmer`).
  Avoids plugin/core package collision checks during Hermes plugin builds like `nixai`.
  Taking the package from the interpreter hermes-agent itself was built with keeps the plugin builds on the same Python version as Hermes.

### Common Workflows

- **Adding an Overlay**: Create a new `.nix` file in the `overlays/` directory.
- **Applying an Overlay**: Overlays are typically applied in the `flake.nix` configuration for NixOS or Home-Manager.
