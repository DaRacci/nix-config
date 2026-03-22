# Stylix

Applies shared system theme defaults with Stylix.

- **Entry point**: [stylix.nix](../../../../../modules/nixos/core/stylix.nix)

---

## Overview

This module imports Stylix and enables dark Tokyo Night theming on non-headless hosts by default.

---

## Options

{{#include ../../../../generated/core-stylix-options.md}}

---

## Behaviour

When enabled, module:

- imports `inputs.stylix.nixosModules.stylix` unless function argument `importExternals = false`,
- sets `stylix.enable = true`,
- sets `stylix.polarity = "dark"`, and
- uses Tokyo Night dark Base16 scheme from `tinted-schemes` input.

---

## Usage Example

```nix
{ ... }: {
  core.stylix.enable = true;
}
```

---

## Operational Notes

- Module is intended for graphical hosts.
- Theme source is `${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-dark.yaml`.
