# Singleton overlay

`overlays/singleton.nix` builds a small set of packages from raw nixpkgs file inputs.

## Behavior

- String entries in `singletonInputs` use `pkgs.callPackage` on `inputs.<name>`.
- Attr entries can provide `name` plus a custom `value` function.
- Overlay exports package under explicit singleton key, not `pkg.name`, so package metadata cannot trigger self-referential lookup.

## Current inputs

- `tabby`
- `tabby-agent`

## Notes

Use explicit overlay key when package name from derivation can differ from input name.
