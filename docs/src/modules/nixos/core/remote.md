# Remote Access

Provides optional remote desktop and game-streaming capabilities for desktop hosts.

- **Entry point**: `modules/nixos/core/remote.nix`

______________________________________________________________________

## Overview

This module exposes `core.remote` with two independent sub-features:

| Sub-feature | Implementation | Purpose |
|---|---|---|
| Remote Desktop | xrdp | Full desktop access over RDP |
| Streaming | Sunshine | Low-latency game or desktop streaming |

______________________________________________________________________

## Options

### `core.remote.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Master switch. Nothing in this module activates unless this is `true`.

### `core.remote.remoteDesktop.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Enable xrdp-based remote desktop access.

### `core.remote.remoteDesktop.startCommand`

| | |
|---|---|
| Type | `string` |
| Default | `"gnome-session"` |

Command xrdp uses as `defaultWindowManager`.

### `core.remote.streaming.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Enable Sunshine streaming server.

______________________________________________________________________

## Behaviour

When `core.remote.enable = true`:

- `remoteDesktop.enable` turns on `services.xrdp`, sets `defaultWindowManager`, and opens firewall for RDP.
- `streaming.enable` turns on `services.sunshine`, enables auto-start, opens firewall, and sets `capSysAdmin = true`.
- if Home Manager is present, streaming also persists `.config/sunshine` through shared Home Manager module.

______________________________________________________________________

## Hyprland Integration

When both `core.remote.streaming.enable` and `programs.hyprland.enable` are `true`, module additionally:

- sets `services.sunshine.settings.output_name = "3"`,
- adds two Sunshine application entries named `Shared Desktop` and `Exclusive Desktop`,
- creates headless output at login with `hyprctl output create headless`, and
- keeps `HEADLESS-2` disabled until Sunshine prep commands enable it.

| Application | Behaviour |
|---|---|
| **Shared Desktop** | Enables `HEADLESS-2` at client resolution and leaves physical monitors active. |
| **Exclusive Desktop** | Enables `HEADLESS-2`, saves active physical monitor state to `$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json`, disables physical monitors, then restores them on disconnect. |

______________________________________________________________________

## Usage Examples

### Streaming only

```nix
{ ... }: {
  core.remote = {
    enable = true;
    streaming.enable = true;
  };
}
```

### RDP only

```nix
{ ... }: {
  core.remote = {
    enable = true;
    remoteDesktop = {
      enable = true;
      startCommand = "hyprland";
    };
  };
}
```

______________________________________________________________________

## Operational Notes

- Two sub-features are independent. You can enable streaming without RDP, or RDP without streaming.
- Sunshine persistence and Hyprland settings are only added when Home Manager is present in system configuration.
- Hyprland-specific Sunshine application entries are only added when both streaming and Hyprland are enabled.
