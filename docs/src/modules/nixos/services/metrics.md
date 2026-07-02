# Metrics & Hacompanion — Metrics Collection & Home Assistant Integration

## Purpose

Comprehensive metrics collection and integration with Home Assistant via `hacompanion`.

## Entry Point

- **Main file**: [metrics.nix](../../../../../modules/nixos/services/metrics.nix)
- **Upstream**: [Hacompanion GitHub Repository](https://github.com/tobias-kuendig/hacompanion)

#### Options

{{#include ../../../../generated/services-metrics-options.md}}

## Architecture / Services / Scope

- **hacompanion** — Home Assistant companion daemon that publishes system sensors (CPU, memory, storage, uptime, and more) to Home Assistant. It uses a generated TOML configuration file and loads the Home Assistant API token from `sops.secrets.HACOMPANION_ENV`.
- **upgradeStatus** — reports NixOS upgrade state (idle / running / failed / dirty). When `upgradeStatus.uptimeKuma.enable` is set, it also sends heartbeat notifications to Uptime Kuma on successful upgrades.

## Secrets

- `HACOMPANION_ENV` — Home Assistant API token, declared in `hosts/secrets.yaml` and consumed via `EnvironmentFile`.
- `UPGRADE_STATUS_ID` — Uptime Kuma push monitor ID (host-level `secrets.yaml`), required when `upgradeStatus.uptimeKuma.enable` is set.

## Operational Notes / Assumptions

- Hacompanion runs as a `DynamicUser` with its state in `/var/lib/hacompanion`.
- The `upgradeStatus` feature can integrate with Uptime Kuma to provide heartbeat notifications for successful system upgrades.

### Usage Example

```nix
{ ... }: {
  services.metrics.hacompanion = {
    enable = true;
    sensor.cpu_temp.enable = true;
    sensor.memory.enable = true;
    storage.main = {
      name = "Main OS Drive";
      sensors.used = true;
    };
  };
}
```

## References

- [Hacompanion GitHub Repository](https://github.com/tobias-kuendig/hacompanion)
