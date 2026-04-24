# Hosts Overview

## Purpose

This section covers the configuration of individual host machines. This repository uses an automatic discovery system to manage hosts based on their device type.

## Entry Points

- `hosts/`: Root directory for all host configurations.
- `hosts/desktop/`: Configurations for desktop systems.
- `hosts/laptop/`: Configurations for laptop systems.
- `hosts/server/`: Configurations for server systems.
- `hosts/shared/`: Shared configuration modules applied across multiple hosts.
- `hosts/secrets.yaml`: Root-level encrypted secrets for host configurations.

## Key Options/Knobs

Host-specific configurations are found in `hosts/{device-type}/{hostname}/default.nix`. Global options shared across all hosts are in `hosts/shared/global/`.

## Common Workflows

- **Adding a New Host**: Create a directory for the host in the appropriate device type category and add a `default.nix`.
- **Modifying a Host**: Update the `default.nix` or associated files in the host's directory.

## References

- [Adding a New Host](../development/adding_a_new_host.md)

---

## Decky Loader Lifecycle

When `jovian.decky-loader.enable = true` is set on any host that imports `hosts/shared/optional/gaming.nix`, [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader) is **not** started automatically at boot. Instead it is managed in lock-step with the Steam desktop application:

- **`hosts/shared/optional/gaming.nix`** — overrides the Jovian-provided `decky-loader.service` to remove it from `multi-user.target`, suppresses noisy CSS_Loader health-check log spam via `LogFilterPatterns`, and adds a polkit rule that permits any active local user session to start/stop the system service without a password prompt. All of this is behind a `lib.mkIf (config.jovian.decky-loader.enable or false)` guard so it is a no-op on machines without Jovian.
- **`home/shared/features/games/decky-loader.nix`** — defines a `decky-loader-steam-watch` systemd user service (active for the duration of the graphical session) that polls `~/.steam/steam.pid` every 3 seconds to detect Steam starting, then starts `decky-loader.service`, and uses `tail --pid` to block until Steam exits before stopping it again. The service is only enabled when `osConfig.jovian.decky-loader.enable` is true.

### Log filtering

The CSS_Loader plugin health-checks Steam's internal web interface (port 8080) every few seconds. When Steam is not running these produce continuous journal noise of the form:

```
[CSS_Loader] [FAIL] [css_browserhook.py:437] [Health Check] Cannot connect to host 127.0.0.1:8080 …
```

This is suppressed with the following `LogFilterPatterns` entry on the service (requires systemd ≥ 255):

```
LogFilterPatterns = "~\[CSS_Loader\].*\[Health Check\].*Cannot connect";
```
