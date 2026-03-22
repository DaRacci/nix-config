# Printing

Enables shared printer support for workstation-class NixOS hosts.

- **Entry point**: [printing.nix](../../../../../modules/nixos/core/printing.nix)

---

## Overview

This module enables CUPS printing support on non-server, non-virtual hosts and installs common printer drivers used in this configuration.

When active, it turns on `services.printing`, adds HP and Gutenprint drivers, and includes Brother MFC-L3770CDW driver packages.

---

## Options

{{#include ../../../../generated/core-printing-options.md}}

---

## Behaviour

When both `config.core.enable` and `core.printing.enable` are `true`, module:

- enables `services.printing`,
- installs printer drivers from `pkgs.hplip`, `pkgs.gutenprint`, `pkgs.gutenprint-bin`, `pkgs.cups-filters`, `pkgs.mfcl3770cdwlpr`, and `pkgs.mfcl3770cdwcupswrapper`, and
- adds `lp` to `core.defaultGroups`.

---

## Usage Example

```nix
{ ... }: {
  core.printing.enable = true;
}
```

---

## Operational Notes

- Module does not activate unless top-level `core.enable` is also enabled.
- Default is tuned for physical desktop or laptop systems where local or network printer access is expected.
- `core.defaultGroups = [ "lp" ]` ensures standard users can access printer devices through shared default group handling.
