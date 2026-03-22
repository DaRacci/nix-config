# Containers

Enables Docker-based container runtime defaults.

- **Entry point**: [containers.nix](../../../../../modules/nixos/core/containers.nix)

---

## Overview

This module turns on Docker as primary container backend and configures OCI containers to use Docker. It also enables weekly image pruning and persists Docker state directories.

---

## Options

{{#include ../../../../generated/core-containers-options.md}}

---

## Behaviour

When enabled, module:

- enables `virtualisation.docker`,
- sets `virtualisation.docker.package = pkgs.docker`,
- enables CDI support with `daemon.settings.features.cdi = true`,
- enables weekly `docker autoPrune`,
- sets `virtualisation.oci-containers.backend = "docker"`,
- adds `docker` to `core.defaultGroups`, and
- persists Docker state under `/var/lib/docker`.

Persisted directories include `overlay2`, `image`, `volumes`, `containers`, `containerd`, and `buildkit`.

---

## Usage Example

```nix
{ ... }: {
  core.containers.enable = true;
}
```

---

## Operational Notes

- Module intentionally prefers Docker because current workloads still need features not covered by Podman or `podman-compose`.
- Users receive Docker access through shared `core.defaultGroups` handling.
