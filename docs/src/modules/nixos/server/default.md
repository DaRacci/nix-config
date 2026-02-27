# Server Module

The Server module provides a cluster-aware configuration for server hosts in the flake. It must be explicitly enabled using the `server.enable` option.

## Purpose

The primary purpose of this module is to establish a shared environment for servers in the cluster, defining a coordinator node (`ioPrimaryHost`) and providing helper functions for inter-server communication and attribute collection.

## Entry Point

- `modules/nixos/server/default.nix`

## Special Options and Behaviors

The main configuration entry point is `server.enable`. Once enabled, it sets up the server-specific baseline:

- **Journald Persistence**: Configured with a 14-day retention period and storage limits.
- **Pre-Switch Checks**: Runs `dix` on system activation to report changes between generations.
- **`server.ioPrimaryHost`**: Specifies the hostname of the coordinator host for the cluster. This host runs primary database instances, the reverse proxy, and storage master nodes. This option is typically set on the coordinator host and used by other servers in the cluster for synchronization.

## Example Usage

To use the server module, it must be explicitly enabled in the host configuration.

```nix
# hosts/server/nixmon/default.nix
{
  server = {
    enable = true;
    # Set to the hostname of the cluster's coordinator node
    ioPrimaryHost = "nixio";
  };
}
```

## Operational Notes

- This module provides many helper functions (like `getAllAttrsFunc`, `collectAllAttrs`, etc.) that are used by submodules to gather configuration data from other servers in the cluster.
- These helpers allow for dynamic configuration based on the state of other cluster nodes, such as building a global dashboard or a reverse proxy configuration.
- The `ioPrimaryHost` is a critical component of the cluster, as many services (like Dashy or MinIO) rely on it as the central point of coordination.
