# Locale

Sets shared timezone and locale defaults.

## Purpose

Provide opinionated regional defaults for timezone and locale so all hosts start from a consistent baseline without forcing per-host overrides.

## Entry Point

- **Main file**: [locale.nix](../../../../../modules/nixos/core/locale.nix)

### Options

{{#include ../../../../generated/core-locale-options.md}}

## Architecture / Services / Scope

The module applies an Australian timezone default and enables Australian and US English UTF-8 locales.

## Operational Notes / Assumptions

- Module is enabled by default.
- Because settings use `mkDefault`, the module acts as a baseline rather than a hard override.
