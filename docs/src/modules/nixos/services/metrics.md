## Metrics & Hacompanion

Comprehensive metrics collection and integration with Home Assistant via `hacompanion`.

- **Entry point**: `modules/nixos/services/metrics.nix`
- **Upstream**: [Hacompanion GitHub Repository](https://github.com/tobias-kuendig/hacompanion)

### Special Options

- `services.metrics.hacompanion.enable`: Enable the Home Assistant Companion service.
- `services.metrics.hacompanion.sensor.<name>.enable`: Enable specific built-in sensors (e.g., `cpu_temp`, `memory`, `uptime`).
- `services.metrics.hacompanion.script`: Define custom scripts to expose as sensors or switches in Home Assistant.
- `services.metrics.hacompanion.storage`: Configure monitoring for storage devices and ZFS pools.
- `services.metrics.upgradeStatus.enable`: Enable a specialized sensor for tracking NixOS upgrade status.

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

### Operational Notes

Hacompanion uses a generated TOML configuration file and securely loads the Home Assistant API token from `sops.secrets.HACOMPANION_ENV`. The `upgradeStatus` feature can also integrate with Uptime Kuma to provide heartbeat notifications for successful system upgrades.
