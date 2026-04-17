# Display Manager

Configures the display manager for graphical sessions on desktop and laptop hosts.

- **Entry point**: `modules/nixos/shared/display-manager.nix`

______________________________________________________________________

## Overview

This module sets up [greetd](https://sr.ht/~kennylevinsen/greetd/) with [tuigreet](https://github.com/apognu/tuigreet) as the default display manager. It is automatically enabled on any host where `host.device.isHeadless` is `false`.

______________________________________________________________________

## Options

### `custom.display-manager.enable`

| | |
|---|---|
| Type | `bool` |
| Default | `!config.host.device.isHeadless` |

Enable the custom display manager configuration. Automatically disabled on headless (server) hosts.

______________________________________________________________________

## Behaviour

When enabled, greetd is started with tuigreet providing a terminal-based greeter that:

- Remembers the last logged-in user (`--remember`)
- Remembers the last selected session (`--remember-session`)
- Discovers Wayland sessions from `services.displayManager.sessionPackages`
- Discovers X sessions from `services.displayManager.sessionPackages`

The greeter cache is persisted to `/var/cache/tuigreet` on impermanence-enabled hosts.

______________________________________________________________________

## Operational Notes

- greetd runs as the `greeter` user.
- Both Wayland (`wayland-sessions`) and X11 (`xsessions`) session paths are dynamically constructed from installed session packages, so adding a new window manager package is sufficient to make it appear in the greeter.
