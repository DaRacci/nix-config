# Remote Access

Provides optional remote desktop and game-streaming capabilities for desktop hosts.

- **Entry point**: `modules/nixos/core/remote.nix`

______________________________________________________________________

## Overview

This module exposes a top-level `core.remote` option namespace with two independent sub-features:

| Sub-feature | Implementation | Purpose |
|---|---|---|
| Remote Desktop | xrdp | Full desktop access over RDP |
| Streaming | Sunshine | Low-latency game/desktop streaming (Moonlight compatible) |

______________________________________________________________________

## Options

### `core.remote.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Master switch. Nothing in this module activates unless this is `true`.

______________________________________________________________________

### `core.remote.remoteDesktop.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Enable RDP remote desktop access via xrdp. Opens firewall for RDP port automatically.

### `core.remote.remoteDesktop.startCommand`

| | |
|---|---|
| Type | `string` |
| Default | `"gnome-session"` |

Command xrdp uses to launch remote desktop session.

______________________________________________________________________

### `core.remote.streaming.enable`

| | |
|---|---|
| Type | `bool` |
| Default | disabled |

Enable Sunshine game-streaming server. Opens firewall, enables auto-start, and grants `CAP_SYS_ADMIN`. Sunshine configuration is persisted through Home Manager when available.

______________________________________________________________________

## Hyprland Integration

When both `core.remote.streaming.enable` and `programs.hyprland.enable` are `true`, module additionally:

- Creates virtual headless monitor on startup with `hyprctl output create headless`.
- Registers two pre-configured Sunshine application entries.

| Application | Behaviour |
|---|---|
| **Shared Desktop** | Creates headless monitor sized to client resolution alongside physical monitors. |
| **Exclusive Desktop** | Creates headless monitor, disables physical monitors for duration of stream, then restores them on disconnect. |

Physical monitor state is saved to `$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json` before disabling and restored from that file when stream ends.

______________________________________________________________________

## Usage Example

```nix
{ ... }: {
  core.remote = {
    enable = true;

    streaming.enable = true;

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
- Sunshine configuration persistence is only added when Home Manager is present in system configuration.
- Hyprland-specific Sunshine application entries are only added when both streaming and Hyprland are enabled.
