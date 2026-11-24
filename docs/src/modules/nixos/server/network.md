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
- `server.network.openPortsForSources` takes named sources and opens the listed TCP/UDP ports for them:
  - `cluster` matches the private cluster CIDR and only on the cluster interface.
  - A hostname from `data.network.cluster.hosts` matches that host's cluster address and only on the cluster interface.
  - `lan` matches every external subnet on any interface.
- Rules are appended to the `nftables` input chain through the `networking.firewall.extraInputRules` option.
  They apply to new and untracked flows only; established connections are accepted earlier by `conntrack`.
- Every server host also gets the cluster interface (`data.network.cluster.interface`) and `<host>.cluster` host records.
  Internal consumers address peers by `<host>.cluster`, not by a short name or DNS search domain.

## Operational Notes / Assumptions

- Subnets are declared in `data/network.nix`; hosts do not declare them.
- Per-host open ports are declared through `server.network.openPortsForSources`.
- Ports reachable by every cluster host use `openPortsForSources.cluster`;
  prefer naming a single host when only one consumer needs the port.
- The `/etc/hosts` entries are exact names; resolvers do not apply a search domain to them.
  Anything that talks to another host over the cluster must use the `.cluster` suffix.

## References

- [Shared Data](../../../data.md)
- [NixOS Networking](https://nixos.org/manual/nixos/stable/#sec-firewall)
