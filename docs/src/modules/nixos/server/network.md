# Server Network — Centralised Subnets and Firewall

## Purpose

The network module coordinates network subnet definitions and firewall rules, allowing for centralised configuration of subnets and automatic propagation of these settings to other servers in the cluster.

## Entry Point

- **Main file**: `modules/nixos/server/network.nix`

#### Options

{{#include ../../../../generated/server-network-options.md}}

## Architecture / Services / Scope

- This module uses `getIOPrimaryHostAttr` to fetch the `server.network.subnets` configuration from the IO Coordinator (`server.ioPrimaryHost`), ensuring all servers in the cluster are aware of the network structure defined there.
- The module generates `ip saddr` / `ip6 saddr` accept rules for the specified ports, allowing traffic only from the defined subnets.
- These rules are appended to the `nftables` input chain through the `networking.firewall.extraInputRules` option. They apply to new and untracked flows only; established connections are accepted earlier by `conntrack`.

## Operational Notes / Assumptions

- Subnets and per-subnet open ports are declared on the IO Coordinator via `server.network.subnets` and `server.network.openPortsForSubnet`.

## References

- [IO Coordinator](../../../hosts/server/nixio.md)
- [NixOS Networking](https://nixos.org/manual/nixos/stable/#sec-firewall)
