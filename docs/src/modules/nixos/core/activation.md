# Activation

Reports system generation changes during NixOS activation.

## Purpose

Provide visibility into what changed between system generations by comparing the previous and newest generation during NixOS activation, so each upgrade shows a readable package and closure diff.

## Entry Point

- **Main file**: [activation.nix](../../../../../modules/nixos/core/activation.nix)

## Architecture / Services / Scope

When enabled, the module installs an activation script (`system.activationScripts.report-changes`) that:

- locates the previous and newest system profile generations under `/nix/var/nix/profiles`,
- resolves both links to their store paths, and
- runs `nvd diff` between them.

If no previous generation exists yet, the script does nothing.

## Operational Notes / Assumptions

- Diff output is informational only; the script tolerates a non-zero `nvd` exit so activation never fails because of a diff error.
- Default follows top-level `core.enable`, so most hosts get generation diff reporting automatically.
