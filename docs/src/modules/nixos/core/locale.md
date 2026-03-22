# Locale

Sets shared timezone and locale defaults.

- **Entry point**: [locale.nix](../../../../../modules/nixos/core/locale.nix)

---

## Overview

This module provides opinionated regional defaults for timezone and locale. It sets Australia/Sydney timezone and enables Australian and US English UTF-8 locales.

---

## Options

{{#include ../../../../generated/core-locale-options.md}}

---

## Usage Example

```nix
{ ... }: {
  core.locale.enable = true;
}
```

---

## Operational Notes

- Module is enabled by default.
- Because settings use `mkDefault`, this module acts as baseline rather than hard override.
