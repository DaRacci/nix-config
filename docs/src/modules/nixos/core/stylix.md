# Stylix

Applies shared system theme defaults with Stylix.

- **Entry point**: `modules/nixos/core/stylix.nix`

______________________________________________________________________

## Overview

This module imports Stylix and enables dark Tokyo Night theming on non-headless hosts by default.

______________________________________________________________________

## Options

### `core.stylix.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `!config.host.device.isHeadless` |

Enable Stylix configuration. Default disables theming on headless hosts.

______________________________________________________________________

## Behaviour

When enabled, module:

- imports `inputs.stylix.nixosModules.stylix` unless function argument `importExternals = false`,
- sets `stylix.enable = true`,
- sets `stylix.polarity = "dark"`, and
- uses Tokyo Night dark Base16 scheme from `tinted-schemes` input.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.stylix.enable = true;
}
```

______________________________________________________________________

## Operational Notes

- Module is intended for graphical hosts.
- Theme source is `${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-dark.yaml`.
