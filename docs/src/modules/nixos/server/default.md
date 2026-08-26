# Server Module

The Server module provides a cluster-aware configuration for server hosts in the flake. It must be explicitly enabled using the `server.enable` option.

## Purpose

The primary purpose of this module is to establish a shared environment for servers in the cluster, defining coordinator nodes for discrete roles (IO, monitoring, database, storage, identity) and providing helper functions for inter-server communication and attribute collection.

## Entry Point

- **Main file**: `modules/nixos/server/default.nix`

### Options

{{#include ../../../../generated/server-options.md}}

## Architecture / Services / Scope

### Special Options and Behaviors

The main configuration entry point is `server.enable`. Once enabled, it sets up the server-specific baseline:

- **Journald Persistence**: Configured with a 7-day retention period, 256MB total max disk usage, and 512MB keep-free threshold. Per-file size is set to 32MB (1/8 of max use) to allow proper log rotation with ~7 archived files. All limits are defined as `let` variables in the module for consistency between the daemon config and the activation vacuum script. The activation script runs `journalctl --vacuum` on every deploy to immediately enforce the limits on existing logs.
- **Pre-Switch Checks**: Runs `dix` on system activation to report changes between generations.
- **`server.ioPrimaryHost`**: Specifies the hostname of the IO Coordinator. This host operates the reverse proxy for handling incoming traffic and manages IO-level coordination. This option is typically set on the coordinator host and used by other servers in the cluster for synchronization.
- **`server.monitoringPrimaryHost`**: Specifies the hostname of the Monitoring Coordinator. This host runs Prometheus, Loki, Grafana, and Alertmanager for centralized observability across the cluster.
- **`server.databasePrimaryHost`**: Specifies the hostname of the Database Coordinator. This host runs primary database instances for centralized data persistence across the cluster.
- **`server.storagePrimaryHost`**: Specifies the hostname of the Storage Coordinator. This host runs primary file and block storage services for centralized data serving across the cluster.
- **`server.authPrimaryHost`**: Specifies the hostname of the Identity Coordinator. This host runs primary authentication and authorization services for centralized identity management across the cluster.

### Example Usage

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

## Operational Notes / Assumptions

### Generic Primary-Host Helpers

Generic helpers parameterized by any primary-host option value. These are used by submodules to check role assignment and fetch remote configuration:

- **`isPrimaryHost primaryHost value`**: Returns `true` if `value` matches `primaryHost`. Accepts either a raw hostname string or an attrset with a `host.name` attribute.
- **`isThisPrimaryHost primaryHost`**: Shorthand for `isPrimaryHost primaryHost config` — checks if the current host is the primary for a given role.
- **`getPrimaryHostConfig primaryHost`**: Returns the NixOS configuration of the host designated as the primary for a given role. On the primary host itself this returns `config` locally; on other hosts it fetches the remote configuration via `self.nixosConfigurations`.
- **`getPrimaryHostAttr primaryHost attrPath`**: Retrieves a specific attribute (expressed as a dot-separated path) from the primary host's configuration.
- **`getOthersWhereExcept primaryHost func`**: Returns a list of server hostnames (excluding the given primary host) where `func` returns `true`. Useful for discovering non-primary nodes that match certain criteria.

### Backward-Compatible IO Helpers

The existing IO-specific helpers (`isIOPrimaryHost`, `isThisIOPrimaryHost`, `primaryIOHostConfig`, `getIOPrimaryHostAttr`, `getOthersWhere`) remain available and now delegate to the generic helpers. They behave identically but are hard-wired to `server.ioPrimaryHost`. New submodules should prefer the generic helpers for role-agnostic code.

### Server Attribute Collection

- This module provides many helper functions (like `getAllAttrsFunc`, `collectAllAttrs`, etc.) that are used by submodules to gather configuration data from other servers in the cluster.
- These helpers allow for dynamic configuration based on the state of other cluster nodes, such as building a global dashboard or a reverse proxy configuration.
- The IO Coordinator is a critical component of the cluster, as many services (like Dashy or shared ingress) rely on it as the central point of coordination.

## References

- [IO Coordinator](../../../hosts/server/nixio.md)
- [Monitoring Coordinator](../../../hosts/server/nixmon.md)
- [Database Coordinator](../../../hosts/server/nixdb.md)
- [Storage Coordinator](../../../hosts/server/nixstor.md)
- [Identity Coordinator](../../../hosts/server/nixauth.md)
