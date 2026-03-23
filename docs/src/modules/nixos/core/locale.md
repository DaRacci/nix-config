# Locale

Sets shared timezone and locale defaults.

- **Entry point**: `modules/nixos/core/locale.nix`

---

## Overview

This module provides opinionated regional defaults for timezone and locale. It sets Australia/Sydney timezone and enables Australian and US English UTF-8 locales.

---

## Options

### `core.locale.enable`

|         |        |
| ------- | ------ |
| Type    | `bool` |
| Default | `true` |

Enable locale baseline configuration.

---

## Behaviour

When enabled, module sets:

- `time.timeZone = "Australia/Sydney"`,
- `i18n.defaultLocale = "en_AU.UTF-8"`, and
- `i18n.supportedLocales = [ "en_AU.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ]`.

All values use `mkDefault`, so host-specific configuration can still override them.

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
