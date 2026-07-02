# Singleton Overlay — Packages from Raw Input Sources

## Purpose

`overlays/singleton.nix` builds a small set of packages from raw nixpkgs file inputs, exporting each under an explicit overlay key.

## Entry Point

- **Main file**: [`overlays/singleton.nix`](../../../overlays/singleton.nix)

## Architecture / Services / Scope

- String entries in `singletonInputs` use `pkgs.callPackage` on `inputs.<name>`.
- Attr entries can provide `name` plus a custom `value` function.
- The overlay exports each package under an explicit singleton key, not `pkg.name`, so package metadata cannot trigger self-referential lookup.

## Operational Notes / Assumptions

- Use an explicit overlay key when the package name from the derivation can differ from the input name.
