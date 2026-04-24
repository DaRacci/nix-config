# Hosts Overview

## Purpose

This section covers configuration of individual host machines. Repository uses automatic discovery system to manage hosts based on device type.

## Entry Points

- `hosts/`: Root directory for all host configurations.
- `hosts/desktop/`: Configurations for desktop systems.
- `hosts/laptop/`: Configurations for laptop systems.
- `hosts/server/`: Configurations for server systems.
- `hosts/shared/`: Shared host configuration still used across multiple hosts.
- `hosts/secrets.yaml`: Root-level encrypted secrets for host configurations.

## Key Options/Knobs

Host-specific configurations live in `hosts/{device-type}/{hostname}/default.nix`.

Shared NixOS behavior that used to live under `hosts/shared/` is being migrated into reusable modules under `modules/nixos/core/`. Hosts now typically enable these with top-level `core.*` options instead of importing host-shared files directly.

Examples:

- `core.containers.enable = true;`
- `core.gaming.enable = true;`
- `core.virtualisation.enable = true;`
- `core.networking.tailscale.enable = true;`

Global options still shared across all hosts remain in `hosts/shared/global/`.

## Common Workflows

- **Adding new host**: Create directory for host in appropriate device type category and add `default.nix`.
- **Modifying host**: Update `default.nix`, associated files in host directory, or relevant module under `modules/nixos/core/`.

## References

- [Adding a New Host](../development/adding_a_new_host.md)

______________________________________________________________________

## Decky Loader Lifecycle

When `jovian.decky-loader.enable = true` is set on host with `core.gaming.enable = true`, [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader) is **not** started automatically at boot. Instead it is managed in lock-step with Steam desktop application:

- **`modules/nixos/core/gaming.nix`** — overrides Jovian-provided `decky-loader.service` to remove it from `multi-user.target`, suppresses noisy CSS_Loader health-check log spam via `LogFilterPatterns`, and adds polkit rule that permits any active local user session to start/stop system service without password prompt. All of this is behind `lib.mkIf (config.jovian.decky-loader.enable or false)` guard, so it is no-op on machines without Jovian.
- **Home-Manager shared module injected by `modules/nixos/core/gaming.nix`** — defines `decky-loader-steam-watch` systemd user service, active for duration of graphical session. It polls `~/.steam/steam.pid` every 3 seconds to detect Steam starting, then starts `decky-loader.service`, and uses `tail --pid` to block until Steam exits before stopping it again. Service is only enabled when `osConfig.jovian.decky-loader.enable` is true.

### Log filtering

CSS_Loader plugin health-checks Steam's internal web interface (port 8080) every few seconds. When Steam is not running these produce continuous journal noise of form:

```
[CSS_Loader] [FAIL] [css_browserhook.py:437] [Health Check] Cannot connect to host 127.0.0.1:8080 …
```

This is suppressed with following `LogFilterPatterns` entry on service (requires systemd ≥ 255):

```
LogFilterPatterns = "~\\[CSS_Loader\\].*\\[Health Check\\].*Cannot connect";
```
