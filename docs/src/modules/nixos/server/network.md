# Server Network — Centralised Subnets and Firewall

## Purpose

The network module coordinates network subnet definitions and firewall rules.
Subnets come from the shared `data/network.nix` file and apply to every server host.

## Entry Point

- **Main file**: `modules/nixos/server/network.nix`

### Options

{{#include ../../../../generated/server-network-options.md}}

## Architecture / Services / Scope

- Subnets are read directly from `self.data.network.subnets`, documented in [Shared Data](../../../data.md).
  There is no per-host subnet option.
- The module generates `ip saddr` / `ip6 saddr` accept rules for the specified ports, allowing traffic only from the defined subnets.
- These rules are appended to the `nftables` input chain through the `networking.firewall.extraInputRules` option.
  They apply to new and untracked flows only; established connections are accepted earlier by `conntrack`.

## Operational Notes / Assumptions

- Subnets are declared in `data/network.nix`; hosts do not declare them.
- Per-host open ports are declared through `server.network.openPortsForSubnet`.

## References

- [Shared Data](../../../data.md)
- [NixOS Networking](https://nixos.org/manual/nixos/stable/#sec-firewall)
