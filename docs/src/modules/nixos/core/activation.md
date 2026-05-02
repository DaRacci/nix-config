# Activation

Reports system generation changes during NixOS activation.

- **Entry point**: `modules/nixos/core/activation.nix`

______________________________________________________________________

## Overview

This module adds activation-time diff reporting with [`nvd`](https://github.com/vlinkz/nvd). During activation it compares previous and new system generations and prints package and closure changes.

______________________________________________________________________

## Options

### `core.activation.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `config.core.enable` |

Enable activation diff reporting.

______________________________________________________________________

## Behaviour

When enabled, module installs `system.activationScripts.report-changes` that:

- finds previous and newest system profile links under `/nix/var/nix/profiles`,
- resolves both links to store paths, and
- runs `nvd diff` between them.

If no previous generation exists yet, script does nothing.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.activation.enable = true;
}
```

______________________________________________________________________

## Operational Notes

- Diff output is informational only. Script ends with `|| true`, so activation does not fail if `nvd diff` returns non-zero.
- Default follows top-level `core.enable`, so most hosts get generation diff reporting automatically.
