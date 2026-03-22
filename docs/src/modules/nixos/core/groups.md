# Groups

Applies shared extra group membership to all declared users.

- **Entry point**: [groups.nix](../../../../../modules/nixos/core/groups.nix)

---

## Overview

This module defines `core.defaultGroups`, shared list of Unix groups appended to every configured standard user. Other core modules use this option to grant access to subsystems like audio, networking, Docker, printing, and virtualisation.

---

## Options

{{#include ../../../../generated/core-groups-options.md}}

---

## Behaviour

When `core.defaultGroups` is non-empty, module rewrites `users.users` entries so each declared user receives `extraGroups = mkAfter cfg.defaultGroups`.

This means module appends shared groups after any user-specific group configuration instead of replacing it.

---

## Usage Example

```nix
{ ... }: {
  core.defaultGroups = [
    "audio"
    "network"
    "lp"
  ];
}
```

---

## Operational Notes

- This module has no enable flag. It activates whenever `core.defaultGroups` contains values.
- Group assignment applies to every user passed through module argument `users`.
