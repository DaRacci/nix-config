# Server Network — Centralized Subnets and Firewall

## Purpose

The network module coordinates network subnet definitions and firewall rules, allowing for centralized configuration of subnets and automatic propagation of these settings to other servers in the cluster.

## Entry Point

- **Main file**: `modules/nixos/server/network.nix`

#### Options

{{#include ../../../../generated/server-network-options.md}}

## Architecture / Services / Scope

- This module uses `getIOPrimaryHostAttr` to fetch the `server.network.subnets` configuration from the `ioPrimaryHost`, ensuring all servers in the cluster are aware of the network structure defined on the coordinator host.
- The module automatically generates `iptables` and `ip6tables` rules for the specified ports, allowing traffic only from the defined subnets.
- These rules are added to the `nixos-fw` chain and are managed through the `networking.firewall.extraCommands` and `networking.firewall.extraStopCommands` options.

## Operational Notes / Assumptions

- Subnets and per-subnet open ports are declared on the coordinator host via `server.network.subnets` and `server.network.openPortsForSubnet`.

## References

- [NixOS Networking](https://nixos.org/manual/nixos/stable/#sec-firewall)
