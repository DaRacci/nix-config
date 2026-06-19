# Remote Access

Provides optional remote desktop and game-streaming capabilities for desktop hosts.

- **Entry point**: [remote.nix](../../../../../modules/nixos/core/remote.nix)

---

## Overview

This module exposes `core.remote` with two independent sub-features:

| Sub-feature    | Implementation | Purpose                               |
| -------------- | -------------- | ------------------------------------- |
| Remote Desktop | xrdp           | Full desktop access over RDP          |
| Streaming      | Sunshine       | Low-latency game or desktop streaming |

---

## Options

{{#include ../../../../generated/core-remote-options.md}}

---

## Behaviour

When `core.remote.enable = true`:

- `remoteDesktop.enable` turns on `services.xrdp`, sets `defaultWindowManager`, and opens firewall for RDP.
- `streaming.enable` turns on `services.sunshine`, opens firewall for TCP 47989, and sets `capSysAdmin = true`.
- Sunshine does not run continuously. A **socket-activated TCP proxy** on port 47989 starts Sunshine on-demand when a client connects.
- When the client disconnects and no new connection arrives for 5 minutes, the proxy exits and Sunshine stops.
- if Home Manager is present, streaming also persists `.config/sunshine` through shared Home Manager module.

---

## Hyprland Integration

When both `core.remote.streaming.enable` and `programs.hyprland.enable` are `true`, module additionally:

- sets `services.sunshine.settings.output_name = "3"`,
- adds two Sunshine application entries named `Shared Desktop` and `Exclusive Desktop`,
- creates headless output at login via Home Manager, and
- keeps `HEADLESS-2` disabled by default until Sunshine prep commands enable it.

### Lua Mode Handling

If Hyprland is in Lua mode (`programs.hyprland.configType = "lua"`), the shared
Home Manager module uses Lua-safe equivalents:

- **Startup hook**: `settings.on` with `hyprland.start` event triggers
  `hyprctl output create headless`.
- **Monitor rule**: `{ output = "HEADLESS-2"; disabled = true; }` (attrset form
  instead of old string).
- **Screencopy permission**: routed through
  `wayland.windowManager.hyprland.custom-settings.permission.screenCopy`,
  which handles both Lua and hyprlang modes automatically.

For hyprlang mode, the old string forms (`exec-once`, `monitor = "HEADLESS-2,disable"`) are used unchanged.

| Application           | Behaviour                                                                                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Shared Desktop**    | Enables `HEADLESS-2` at client resolution and leaves physical monitors active.                                                                                                             |
| **Exclusive Desktop** | Enables `HEADLESS-2`, saves active physical monitor state to `$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json`, disables physical monitors, then restores them on disconnect. |

---

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

---

## Operational Notes

- Two sub-features are independent. You can enable streaming without RDP, or RDP without streaming.
- Sunshine persistence and Hyprland settings are only added when Home Manager is present in system configuration.
- Hyprland-specific Sunshine application entries are only added when both streaming and Hyprland are enabled.

---

## On-Demand Activation & Idle Stop

Sunshine stays on its standard port family rooted at **TCP/UDP 47989–47990+** (no port-family offset). External inbound TCP **47989** is firewall-redirected to internal proxy port **48989**. The proxy wakes Sunshine and forwards to `127.0.0.1:47989`.

| Stage                 | What happens                                                                                                                                                                                                           |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Firewall redirect** | `iptables` NAT prerouting rule redirects inbound TCP `:47989` to local `:48989`. A conntrack-based filter accept allows only redirected traffic into `:48989`; `:48989` is not broadly exposed.                        |
| **Socket activation** | `sunshine-proxy.socket` listens on TCP `:48989`. First connection activates `sunshine-proxy.service`.                                                                                                                  |
| **Proxy start**       | `sunshine-proxy.service` pulls in `sunshine.service` via systemd dependencies, then `sunshine-proxy-wrapper` polls until port 47989 is open and exec-s into `systemd-socket-proxyd` forwarding to `127.0.0.1:47989`.   |
| **Active streaming**  | Sunshine handles Moonlight/Sunshine client traffic on its standard port family. The proxy relays only the initial control connection transparently. Proxy `bindsTo` Sunshine — if Sunshine crashes proxy goes with it. |
| **Idle stop**         | After 300s with no connection, `systemd-socket-proxyd` exits. Sunshine has `Restart=no` and `StopWhenUnneeded=true` with no remaining active referrer, so systemd stops it.                                            |

### Dependency Model

```
sunshine-proxy.socket (:48989)
    ↓ activates
sunshine-proxy.service  ──bindsTo──→  sunshine.service (:47989)
```

No cycle: proxy starts Sunshine, proxy `bindsTo` Sunshine (proxy dies if Sunshine fails), Sunshine uses `StopWhenUnneeded` (stops when proxy exits).

### Firewall Flow

```
External client → TCP :47989
    ↓ (NAT PREROUTING REDIRECT)
Local port :48989
    ↓ (conntrack ctorigdstport 47989 match → nixos-fw-accept)
sunshine-proxy.socket
    ↓
sunshine-proxy.service → sunshine.service (:47989)
```

Redirect covers only inbound network traffic. Locally-originated traffic to `:47989` (e.g. from Moonlight running on the same machine) is unaffected.

### Caveats

- **No LAN discovery while idle.** Sunshine needs to run for mDNS/SSDP advertisements to appear on LAN. While stopped (idle), clients will not auto-discover the host. Users must add the host manually by IP/hostname in Moonlight or use a previously-added host entry (Moonlight remembers known hosts).
- **TCP wake only.** This proxy covers the control/initial TCP connection on 47989. Sunshine's UDP audio/video streams (standard port range) will only work after Sunshine runs. Since Sunshine sets up its UDP sockets itself after startup, no UDP wake is needed in practice (the rendezvous happens over TCP first).
- **Delayed first connect.** The first TCP connection may stall ~1–2 seconds while Sunshine starts up. Clients (Moonlight) retry or timeout gracefully.
- **Firewall.** Sunshine opens its standard ports via `openFirewall`. The redirect only touches TCP 47989 for the wake path. No port-family offset anymore — all media/data ports remain at standard values.
- **Redirect scope.** The firewall redirect applies to inbound network traffic only. Local loopback connections to `:47989` bypass the redirect and reach Sunshine directly if it is already running.
