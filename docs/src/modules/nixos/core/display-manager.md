# Display Manager

Configures display manager for graphical sessions on desktop and laptop hosts.

- **Entry point**: `modules/nixos/core/display-manager.nix`

______________________________________________________________________

## Overview

This module sets up [greetd](https://sr.ht/~kennylevinsen/greetd/) with [tuigreet](https://github.com/apognu/tuigreet) as default display manager. It is automatically enabled on hosts where `host.device.isHeadless = false`.

______________________________________________________________________

## Options

### `core.display-manager.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `!config.host.device.isHeadless` |

Enable display manager configuration. Automatically disabled on headless hosts.

______________________________________________________________________

## Behaviour

When enabled, greetd starts with tuigreet providing terminal-based greeter that:

- Remembers last logged-in user with `--remember`
- Remembers last selected session with `--remember-session`
- Discovers Wayland sessions from `services.displayManager.sessionPackages`
- Discovers X sessions from `services.displayManager.sessionPackages`

Greeter cache is persisted to `/var/cache/tuigreet` on impermanence-enabled hosts.

______________________________________________________________________

## Operational Notes

- `greetd` runs as `greeter` user.
- Both Wayland (`wayland-sessions`) and X11 (`xsessions`) session paths are built dynamically from installed session packages, so adding new window manager package is enough to make it appear in greeter.
