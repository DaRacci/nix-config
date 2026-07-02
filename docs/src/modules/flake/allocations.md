# Flake Allocations — Cross-Host Cluster Configuration

## Purpose

The flake allocations module declares cluster-wide configuration options at the flake level. Rather than configuring each NixOS system independently, allocations let you declare concerns like which machines have accelerators, which server coordinates I/O, and which servers act as distributed builders — in a single place — and then propagate those values into every host configuration.

## Entry Point

- **Main file**: [`modules/flake/allocations.nix`](../../../../modules/flake/allocations.nix)
- **Supporting files**:
  - **Supporting file**: [`modules/flake/apply/system.nix`](../../../../modules/flake/apply/system.nix) — maps allocations onto NixOS options per system
  - **Supporting file**: [`modules/flake/apply/home-manager.nix`](../../../../modules/flake/apply/home-manager.nix) — Home-Manager apply (placeholder)
  - **Supporting file**: [`flake/nixos/flake-module.nix`](../../../../flake/nixos/flake-module.nix) — sets the actual allocation values
  - **Supporting file**: [`lib/builders/default.nix`](../../../../lib/builders/default.nix) — builder that consumes allocations

## Architecture / Services / Scope

The allocation system has three layers:

1. **Option Definitions** (`modules/flake/allocations.nix`) — declares the available allocation options.
1. **Configuration** (`flake/nixos/flake-module.nix`) — sets the actual values for those options.
1. **Apply Modules** (`modules/flake/apply/`) — propagate allocation values into each NixOS or Home-Manager configuration via `specialArgs`.

### Data Flow

```
allocations.nix          flake-module.nix            apply/system.nix
┌──────────────┐   ┌──────────────────────┐   ┌───────────────────────┐
│ Define opts  │──▶│ Set values           │──▶│ Map to NixOS options  │
│ (types,      │   │ (which host has what)│   │ per system via        │
│  defaults)   │   │                      │   │ specialArgs           │
└──────────────┘   └──────────────────────┘   └───────────────────────┘
```

When a NixOS configuration is built, it receives the `allocations` attribute set and passes it as a `specialArgs` argument. The apply module then conditionally maps those allocations to NixOS module options based on the host's device type.

### Allocation Options

{{#include ../../../generated/allocations-options.md}}

#### `allocations.accelerators`

Maps hostnames to their available hardware accelerators (`cuda`, `rocm`). Used by the builder system to configure `nixpkgs` with the correct `cudaSupport` / `rocmSupport` flags per host. Hosts not listed default to no accelerators. The builder reads `allocations.accelerators.${hostname}` and sets the corresponding nixpkgs config flags.

#### `allocations.hostTypes`

Read-only attribute set mapping device types to their hostnames. Auto-populated from the host-discovery function, which scans the `hosts/` directory structure.

#### Server primary-host allocations

These options each designate a specific server as the primary host for a cluster role (I/O coordination, monitoring, database, storage, authentication). The type of each is constrained to an enum of server hostnames, automatically derived from `hostTypes.server`. Values flow through `apply/system.nix` into the corresponding `server.*` option on each server configuration:

- `allocations.server.ioPrimaryCoordinator` → `server.ioPrimaryHost`
- `allocations.server.monitoringPrimaryHost` → `server.monitoringPrimaryHost`
- `allocations.server.databasePrimaryHost` → `server.databasePrimaryHost`
- `allocations.server.storagePrimaryHost` → `server.storagePrimaryHost`
- `allocations.server.authPrimaryHost` → `server.authPrimaryHost`

#### `allocations.server.distributedBuilders`

List of servers that act as remote builders for distributed builds. Flows into `server.distributedBuilds.builders` on each server configuration.

### Apply Modules

The apply modules bridge flake-level allocations to per-system NixOS options.

`apply/system.nix` is imported during system construction. It receives `allocations` and `deviceType` via `specialArgs` and maps the server allocations onto the corresponding `server.*` options. It uses `optionalAttrs` to only apply server-specific options when `deviceType == "server"`, preventing errors on non-server systems.

`apply/home-manager.nix` is imported by the Home-Manager builder. It is currently a no-op — a placeholder for future home-manager-level allocations.
