# Server Dashboard Module

The Server Dashboard module provides an integrated dashboard for monitoring and accessing services within the server cluster.

## Purpose

The dashboard module integrates with [Dashy](https://dashy.to/) and collects dashboard sections from all servers in the cluster to display on the `ioPrimaryHost`.

## Entry Point

- `modules/nixos/server/dashboard.nix`

## Special Options and Behaviors

The module provides options under `server.dashboard` to define the section for each server:

- **`server.dashboard.name`**: The name of the section in the dashboard, defaulting to the capitalized hostname.
- **`server.dashboard.icon`**: An optional icon for the section.
- **`server.dashboard.items`**: A set of dashboard items (with `title`, `icon`, and `url`) to be displayed.
- **`server.dashboard.displayData`**: Arbitrary JSON data to be passed to the dashboard configuration.

## Example Usage

Configure the dashboard section for a server:

```nix
# hosts/server/nixserv/default.nix
{
  server.dashboard = {
    name = "Services";
    icon = "fas fa-server";
    items = {
      "Grafana" = {
        title = "Grafana Dashboard";
        icon = "fas fa-chart-line";
        url = "https://grafana.example.com";
      };
    };
  };
}
```

## Operational Notes

- This module uses `getAllAttrsFunc` to gather `server.dashboard` configurations from all servers in the cluster.
- The aggregated configuration is only applied to the `ioPrimaryHost`, which runs the primary Dashy instance.
- This allows each server to define its own dashboard items, which are then automatically collected and displayed on a single unified dashboard.
