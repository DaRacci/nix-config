# Server Dashboard — Cluster-Wide Service Dashboard

## Purpose

The dashboard module integrates with [Dashy](https://dashy.to/) and collects dashboard sections from all servers in the cluster to display on the IO Coordinator (`server.ioPrimaryHost`). This allows each server to define its own dashboard items, which are then automatically collected and displayed on a single unified dashboard.

## Entry Point

- **Main file**: `modules/nixos/server/dashboard.nix`

### Options

{{#include ../../../../generated/server-dashboard-options.md}}

## Architecture / Services / Scope

- This module uses `getAllAttrsFunc` to gather `server.dashboard` configurations from all servers in the cluster.
- The aggregated configuration is only applied to the IO Coordinator (`server.ioPrimaryHost`), which runs the primary Dashy instance.

## Operational Notes / Assumptions

- Each server defines its own `server.dashboard` section (name, icon, and items) in its host configuration; the items are aggregated cluster-wide.

## References

- [Dashy](https://dashy.to/)
- [IO Coordinator](../../../hosts/server/nixio.md)
