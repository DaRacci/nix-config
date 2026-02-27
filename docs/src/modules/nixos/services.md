# NixOS Services

This section documents the custom NixOS service modules available in this configuration. These modules provide specialized integrations and monitoring capabilities.

## Huntress

Managed EDR (Endpoint Detection and Response) platform that protects systems by detecting malicious footholds used by attackers.

- **Entry point**: `modules/nixos/services/huntress.nix`
- **Upstream**: [Huntress Managed EDR](https://www.huntress.com/platform/managed-edr)

### Special Options

- `services.huntress.accountKeyFile`: Path to a file containing the Huntress account key.
- `services.huntress.organisationKeyFile`: Path to a file containing the Huntress organisation key.

### Usage Example

```nix
{ config, ... }: {
  services.huntress = {
    enable = true;
    accountKeyFile = config.sops.secrets.huntress_account_key.path;
    organisationKeyFile = config.sops.secrets.huntress_org_key.path;
  };
}
```

### Operational Notes

The agent configuration is generated at `/etc/huntress/agent_config.yaml` during the service's `preStart` phase. It merges the provided account and organisation keys using `yaml-merge`. The keys are securely loaded into the service using systemd `LoadCredential`.

______________________________________________________________________

## MCPO (Model Context Protocol Orchestrator)

Orchestrates Model Context Protocol (MCP) servers, providing a centralized way to manage and expose multiple MCP servers.

- **Entry point**: `modules/nixos/services/mcpo.nix`
- **Upstream**: [MCPO GitHub Repository](https://github.com/open-webui/mcpo)

### Special Options

- `services.mcpo.configuration`: An attribute set defining the MCP servers to orchestrate.
- `services.mcpo.apiTokenFile`: Optional path to a file containing an API token for the service.
- `services.mcpo.extraPackages`: Additional packages to include in the service's `PATH`.
- `services.mcpo.helpers`: Read-only attribute set of helper functions for common server types (e.g., `npxServer`, `uvxServer`).

### Usage Example

```nix
{ config, ... }: {
  services.mcpo = {
    enable = true;
    configuration = {
      everything = config.services.mcpo.helpers.npxServer "@modelcontextprotocol/server-everything";
    };
  };
}
```

### Operational Notes

MCPO runs as a `DynamicUser` with a state directory at `/var/lib/mcpo`. The configuration is rendered via `sops.templates` and loaded into the service via systemd credentials. The service's `PATH` includes `bash`, `nodejs`, and `uv` by default to support various MCP server types.

______________________________________________________________________

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

______________________________________________________________________

## Tailscale

Extensions to the standard NixOS Tailscale module, providing easier tag management.

- **Entry point**: `modules/nixos/services/tailscale.nix`
- **Upstream**: [Tailscale Tags Documentation](https://tailscale.com/kb/1018/tags/)

### Special Options

- `services.tailscale.tags`: A list of tags to advertise for this device. These tags are automatically prefixed with `tag:` when passed to `tailscale up`.

### Usage Example

```nix
{ ... }: {
  services.tailscale = {
    enable = true;
    tags = [ "server" "internal" ];
  };
}
```

### Operational Notes

This module simplifies the application of Tailscale tags by automatically constructing the `--advertise-tags` flag. Ensure that the device has the necessary permissions in your Tailscale ACLs to apply the requested tags.
