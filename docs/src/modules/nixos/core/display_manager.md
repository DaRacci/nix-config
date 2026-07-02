# Display Manager

Configures the display manager for graphical sessions on desktop and laptop hosts.

## Purpose

Provide a consistent, terminal-based login experience via greetd and tuigreet on hosts with a display.

## Entry Point

- **Main file**: [display-manager.nix](../../../../../modules/nixos/core/display-manager.nix)

### Options

{{#include ../../../../generated/core-display-manager-options.md}}

## Architecture / Services / Scope

Enabled by default on hosts where `host.device.isHeadless = false`. The greetd greeter runs as the `greeter` user and:

- shows the current time,
- remembers the last logged-in user and last selected session, and
- exposes both Wayland and X11 session directories when `services.displayManager.sessionPackages` is non-empty.

Greeter cache is persisted to `/var/cache/tuigreet` through `host.persistence.directories`.

## Operational Notes / Assumptions

- Both Wayland (`wayland-sessions`) and X11 (`xsessions`) session paths are built dynamically from installed session packages, so adding a new session package is enough to make it appear in the greeter.
