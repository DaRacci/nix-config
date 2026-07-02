# Containers

Enables Docker-based container runtime defaults.

## Purpose

Provide a Docker-backed container runtime for workloads that still rely on Docker-specific features, with automatic image pruning and persistent state.

## Entry Point

- **Main file**: [containers.nix](../../../../../modules/nixos/core/containers.nix)

### Options

{{#include ../../../../generated/core-containers-options.md}}

## Architecture / Services / Scope

When enabled, the module:

- enables `virtualisation.docker` with the default Docker package,
- enables CDI device support in the Docker daemon,
- enables weekly automatic image pruning,
- sets `virtualisation.oci-containers.backend = "docker"`,
- adds `docker` to `core.defaultGroups`, and
- persists Docker state directories under `/var/lib/docker` (overlay storage, images, volumes, containers, containerd, and buildkit data).

## Operational Notes / Assumptions

- Docker is intentionally preferred because current workloads still need features not covered by Podman or `podman-compose`.
- Users receive Docker access through the shared `core.defaultGroups` handling.
