# Server Distributed Builds — Remote Nix Build Distribution

## Purpose

The distributed builds module allows for distributed building of Nix derivations using remote build machines, providing a coordinator host and several build machines to distribute the build load across the server cluster.

## Entry Point

- **Main file**: `modules/nixos/server/distributed-builds.nix`

#### Options

{{#include ../../../../generated/server-distributed-builds-options.md}}

## Architecture / Services / Scope

- This module coordinates the creation of a system user (`builder`) on the build server and adds the necessary SSH keys to allow other hosts to connect.
- On the hosts using the build server, the module automatically configures `nix.distributedBuilds` and sets up the build machines using `nix.buildMachines`.
- The `builder` user is automatically added to `nix.settings.trusted-users` on the build server.
- The module uses `self.nixosConfigurations` to dynamically discover the system architecture of the build machines.

## Operational Notes / Assumptions

- A host declares the build server via `server.distributedBuilder.builders` in its host configuration.

## References

- [NixOS Manual: Distributed Builds](https://nixos.org/manual/nixos/stable/index.html#sec-distributed-builds)
