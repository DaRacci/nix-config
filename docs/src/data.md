# Shared Data and Validation

Multi-use static data lives in `data/`.
Each data file owns one slice with its own validation rules.
Flake outputs expose the aggregate as `self.data` and the validator as `self.validate`.

## Shape

Every data file exports both `data` and `validate`:

```nix
{ v }:
{
  data = { ... };

  validate = lib: data: [
    {
      assertion = data.network.subnets != [ ];
      message = "network subnets must not be empty";
    }
  ];
}
```

`validate` receives the complete aggregate through `data`, so it can inspect other slices.
It returns a list of NixOS-style `{ assertion, message }` `attrsets`.
Returning `[ ]` means the slice has no checks.

The aggregate is assembled in `data/default.nix`:

```nix
{ lib }:
let
  v = import ./_lib.nix { inherit lib; };

  modules = {
    network = import ./network.nix { inherit v; };
    redis = import ./redis { inherit v; };
    site = import ./site.nix { inherit v; };
  };
in
{
  data = lib.mapAttrs (_: module: module.data) modules;
  validate = lib: data: ...;
}
```

Errors are prefixed with `data.<file>:`.

## Current Slices

- `network` — subnets plus CIDR lists derived from them.
  `validate` checks subnet keys, IP keys, and that every subnet has a CIDR.
- `redis` — generated database ID mappings.
- `site` — public domain and administrative email.

## Private Validation Helpers

`data/_lib.nix` contains validation primitives used only by `data/`.
It is not part of `lib.mine`.
Current helpers:

- `unique`: reports duplicate values.
- `range`: reports values outside an inclusive range.
- `keys`: reports missing or stale attribute names.

## Flake Check

`flake/dev/checks.nix` runs the validator through `nix flake check`:

```bash
nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"
```

A non-empty failed-assertion list fails `data-consistency`.
The check prints every failed message and exits non-zero.

## Assertion Shape

The validator follows the NixOS `assertions` pattern:

```nix
{
  assertion = condition;
  message = "shown when the assertion is false";
}
```

`data/default.nix` prefixes every message with `data.<file>:`.
`flake/dev/checks.nix` keeps only failed assertions before failing the check.

## Adding Data

1. Create a file that exports `{ data, validate }`.
1. Register it in `modules` in `data/default.nix`.
1. Add a check to `validate` if the slice has invariants.
1. Use it through `self.data.<name>`.

## Generated Data

Generated data can be used with a pattern like this:

```nix
{
  data = builtins.fromJSON (builtins.readFile ./generated.json);
  validate = lib: data: [ ];
}
```
