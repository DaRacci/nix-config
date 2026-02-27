# Flake Allocations

The flake allocations module defines cross-host configuration options at the flake level. Rather than configuring each NixOS system independently, allocations let you declare cluster-wide concerns — like which machines have GPUs, which server coordinates I/O, and which servers act as distributed builders — in a single place.

## How It Works

The allocation system has three layers:

1. **Option Definitions** (`modules/flake/allocations.nix`) — Declares the available allocation options.
1. **Configuration** (`flake/nixos/flake-module.nix`) — Sets the actual values for those options.
1. **Apply Modules** (`modules/flake/apply/`) — Propagates allocation values into each NixOS or Home-Manager configuration via `specialArgs`.

### Data Flow

```
allocations.nix          flake-module.nix            apply/system.nix
┌──────────────┐   ┌──────────────────────┐   ┌───────────────────────┐
│ Define opts  │──▶│ Set values           │──▶│ Map to NixOS options  │
│ (types,      │   │ (which host has what)│   │ per system via        │
│  defaults)   │   │                      │   │ specialArgs           │
└──────────────┘   └──────────────────────┘   └───────────────────────┘
```

When `mkSystem` builds a NixOS configuration, it receives the `allocations` attribute set and passes it as a `specialArgs` argument. The apply module then conditionally maps those allocations to NixOS module options based on the host's device type.

## Options

### `allocations.accelerators`

Maps hostnames to their available hardware accelerators (`cuda`, `rocm`). Used by the builder system to configure `nixpkgs` with the correct `cudaSupport` / `rocmSupport` flags per host.

```nix
allocations.accelerators = {
  nixmi = [ "cuda" ];
  nixai = [ ];
};
```

Hosts not listed default to no accelerators. The builder (`lib/builders/default.nix`) reads `allocations.accelerators.${hostname}` and sets the corresponding nixpkgs config flags.

### `allocations.hostTypes`

Read-only attribute set mapping device types to their hostnames. Auto-populated from `getHostsByType`, which scans `hosts/` directory structure.

```nix
# Automatically resolves to something like:
allocations.hostTypes = {
  server = [ "nixio" "nixserv" "nixmon" ];
  desktop = [ "nixmi" ];
};
```

### `allocations.server.ioPrimaryCoordinator`

Designates a server as the primary I/O coordinator for the cluster. This is the host that runs primary database instances, the reverse proxy, and storage master nodes.

The type is constrained to an enum of server hostnames (automatically derived from `hostTypes.server`).

```nix
allocations.server.ioPrimaryCoordinator = "nixio";
```

This value flows through `apply/system.nix` into `server.ioPrimaryHost` on each server configuration.

### `allocations.server.distributedBuilders`

List of servers that act as remote builders for distributed builds.

```nix
allocations.server.distributedBuilders = [ "nixserv" ];
```

Flows into `server.distributedBuilder.builders` on each server configuration.

## Apply Modules

The apply modules (`modules/flake/apply/`) bridge flake-level allocations to per-system NixOS options.

### `apply/system.nix`

Imported by `mkSystem` during system construction. Receives `allocations` and `deviceType` via specialArgs. For server-type hosts, it maps:

- `allocations.server.ioPrimaryCoordinator` → `server.ioPrimaryHost`
- `allocations.server.distributedBuilders` → `server.distributedBuilder.builders`

Uses `optionalAttrs` to only apply server-specific options when `deviceType == "server"`, preventing errors on non-server systems.

### `apply/home-manager.nix`

Imported by the Home-Manager builder. Currently a no-op (`mkMerge []`) — exists as a placeholder for future home-manager-level allocations.

## Source Files

| File | Role |
|------|------|
| [`modules/flake/allocations.nix`](../../../modules/flake/allocations.nix) | Option definitions |
| [`modules/flake/apply/system.nix`](../../../modules/flake/apply/system.nix) | NixOS system apply |
| [`modules/flake/apply/home-manager.nix`](../../../modules/flake/apply/home-manager.nix) | Home-Manager apply (placeholder) |
| [`flake/nixos/flake-module.nix`](../../../flake/nixos/flake-module.nix) | Actual configuration values |
| [`lib/builders/default.nix`](../../../lib/builders/default.nix) | Builder that consumes allocations |
