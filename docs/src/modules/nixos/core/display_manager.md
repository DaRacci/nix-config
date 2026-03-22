# Display Manager

Configures display manager for graphical sessions on desktop and laptop hosts.

- **Entry point**: [display-manager.nix](../../../../../modules/nixos/core/display-manager.nix)

---

## Overview

This module sets up [greetd](https://sr.ht/~kennylevinsen/greetd/) with [tuigreet](https://github.com/apognu/tuigreet) as default display manager. It is automatically enabled on hosts where `host.device.isHeadless = false`.

When session packages are present in `services.displayManager.sessionPackages`, module also passes both Wayland and X session directories to `tuigreet`.

---

## Options

{{#include ../../../../generated/core-display-manager-options.md}}

---

## Behaviour

When enabled, greetd starts with tuigreet providing terminal-based greeter that:

- shows current time with `--time`,
- remembers last logged-in user with `--remember`,
- remembers last selected session with `--remember-session`, and
- adds `--sessions` and `--xsessions` only when `services.displayManager.sessionPackages` is non-empty.

Greeter cache is persisted to `/var/cache/tuigreet` through `host.persistence.directories`.

---

## Usage Example

```nix
{ ... }: {
  services.displayManager.sessionPackages = [
    pkgs.hyprland
  ];

  core.display-manager.enable = true;
}
```

---

## Operational Notes

- `greetd` runs as `greeter` user.
- Both Wayland (`wayland-sessions`) and X11 (`xsessions`) session paths are built dynamically from installed session packages, so adding new session package is enough to make it appear in greeter.
