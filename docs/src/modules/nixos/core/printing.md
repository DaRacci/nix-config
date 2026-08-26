# Printing

Enables shared printer support for workstation-class NixOS hosts.

## Purpose

Provide CUPS printing and common printer drivers on non-server, non-virtual hosts so local and network printing work out of the box.

## Entry Point

- **Main file**: [printing.nix](../../../../../modules/nixos/core/printing.nix)

### Options

{{#include ../../../../generated/core-printing-options.md}}

## Architecture / Services / Scope

When both top-level `core.enable` and `core.printing.enable` are on, the module:

- enables `services.printing` with HP and Gutenprint driver stacks plus Brother colour laser driver packages, and
- adds `lp` to `core.defaultGroups`.

## Operational Notes / Assumptions

- Module does not activate unless top-level `core.enable` is also enabled.
- Default is tuned for physical desktop or laptop systems where local or network printer access is expected.
- `lp` group membership is granted through the shared `core.defaultGroups` handling.
