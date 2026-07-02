# Stylix — Shared system theme defaults via Stylix

## Purpose

Apply a consistent dark theme across graphical hosts by importing Stylix and enabling dark Tokyo Night theming by default.

## Entry Point

- **Main file**: [stylix.nix](../../../../../modules/nixos/core/stylix.nix)

## Architecture / Services / Scope

When enabled, module:

- imports `stylix` (skipped when function argument `importExternals = false`),
- enables Stylix with dark polarity, and
- selects the Tokyo Night dark Base16 scheme from the `tinted-schemes` input.

## Operational Notes / Assumptions

- Intended for graphical (non-headless) hosts; enabled by default there.
- Theme source comes from the `tinted-schemes` input.
