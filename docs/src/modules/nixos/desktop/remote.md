# Remote Access

Provides optional remote desktop and game-streaming capabilities for desktop hosts.

- **Entry point**: `modules/nixos/shared/remote.nix`

---

## Overview

This module exposes a top-level `custom.remote` option namespace with two independent sub-features:

| Sub-feature    | Implementation | Purpose                                                   |
| -------------- | -------------- | --------------------------------------------------------- |
| Remote Desktop | xrdp           | Full desktop access over RDP                              |
| Streaming      | Sunshine       | Low-latency game/desktop streaming (Moonlight compatible) |

---

## Options

### `custom.remote.enable`

|         |          |
| ------- | -------- |
| Type    | `bool`   |
| Default | disabled |

Master switch. Nothing in this module activates unless this is `true`.

---

### `custom.remote.remoteDesktop.enable`

|         |          |
| ------- | -------- |
| Type    | `bool`   |
| Default | disabled |

Enable RDP remote desktop access via xrdp. Opens the firewall for the RDP port automatically.

### `custom.remote.remoteDesktop.startCommand`

|         |                   |
| ------- | ----------------- |
| Type    | `string`          |
| Default | `"gnome-session"` |

The command xrdp uses to launch the remote desktop session.

---

### `custom.remote.streaming.enable`

|         |          |
| ------- | -------- |
| Type    | `bool`   |
| Default | disabled |

Enable Sunshine game-streaming server (Moonlight-compatible). Opens the firewall and grants `CAP_SYS_ADMIN`. Sunshine configuration is automatically persisted for impermanent hosts.

---

## Hyprland Integration

When both `custom.remote.streaming.enable` and `programs.hyprland.enable` are `true`, the module additionally:

- Creates a virtual headless monitor on startup (`hyprctl output create headless`).
- Registers two pre-configured Sunshine application entries:

| Application           | Behaviour                                                                                                                         |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Shared Desktop**    | Creates a headless monitor sized to the client resolution alongside physical monitors.                                            |
| **Exclusive Desktop** | Creates the headless monitor and disables all physical monitors for the duration of the stream, then restores them on disconnect. |

The physical monitor state is saved to `$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json` before disabling and restored from that file on stream end.

---

## Usage Example

```nix
{ ... }: {
  custom.remote = {
    enable = true;

    streaming.enable = true;

    remoteDesktop = {
      enable = true;
      startCommand = "hyprland";
    };
  };
}
```

---

## Operational Notes

- The two sub-features are independent; you can enable streaming without enabling RDP and vice versa.
- Sunshine runs as a systemd user service and starts automatically at login.
- Sunshine state is persisted under `.config/sunshine` in the user home directory.
