# Overlays Overview

## Purpose

Overlays allow us to extend or modify the standard `nixpkgs` collection. We use them to add our custom packages, apply patches, or override package versions.

## Architecture / Services / Scope

### Entry Points

- `overlays/`: Directory containing individual overlay definitions.
- `overlays/default.nix`: The main entry point for the overlays. It composes additions (from `pkgs/` and external inputs) and modifications (overrides for upstream packages).

## Operational Notes / Assumptions

### Key Options/Knobs

Overlays themselves don't typically have "knobs," but they affect the available packages and their versions in the `pkgs` set.

### Notable Overrides

- **`kernelPackages.universal-pidff`**: Pinned to upstream commit [`595c65bb`](https://github.com/JacKeTUs/universal-pidff/commit/595c65bb23ad824cb6d8dedb1d74123f622de1cc) from `main`. Provides a newer force-feedback kernel module driver than the version bundled in the current nixpkgs release.
- **`discord`**: Overridden to enable OpenASAR and Vencord.
- **`hermes-agent`**: Local overlay that builds Hermes Agent from upstream source plus patches:
  - [PR #87820](https://github.com/NousResearch/hermes-agent/pull/87820) — desktop renderer build typecheck isolation.
  - [PR #93896](https://github.com/NousResearch/hermes-agent/pull/93896) — home-aware managed detection.
  - The overlay also passes the release version (`2026.9.24` style, read from `hermes_cli/__init__.py` in the locked source). Upstream leaves the `version` argument at its `0.0.0` default in `nix/packages.nix`, which makes plugin installers that enforce a minimum Hermes version refuse to install.
  - The overlay builds `pmPackages` from the locked source's `nix/pm-packages.nix` and passes them in, matching what upstream's `nix/packages.nix` does; `nix/hermes-agent.nix` requires that argument.
- **`hermes-desktop`** (`pkgs/default.nix`): Routes to `pkgs.hermes-agent.hermesDesktop`, exposing the patched Hermes Desktop package as a top-level `pkgs` entry for use in home-manager configs.
- **`fastembed-hermes`**: Overrides `fastembed` from `hermes-agent.python.pkgs` to strip Python deps already bundled in the Hermes sealed uv2nix environment (e.g. `snowballstemmer`). Avoids plugin/core package collision checks during Hermes plugin builds like `nixai`. Taking the package from the interpreter hermes-agent itself was built with keeps the plugin builds on the same Python version as Hermes.

### Common Workflows

- **Adding an Overlay**: Create a new `.nix` file in the `overlays/` directory.
- **Applying an Overlay**: Overlays are typically applied in the `flake.nix` configuration for NixOS or Home-Manager.
