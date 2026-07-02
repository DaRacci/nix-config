# nixserv — Nix Build Server

## Purpose

`nixserv` is the dedicated binary cache and distributed build server for the cluster.
It runs Attic backed by PostgreSQL and S3 storage, and acts as a remote build daemon for distributed Nix builds.

## Entry Point

- **Main file**: [`hosts/server/nixserv/default.nix`](../../../../hosts/server/nixserv/default.nix)

## Architecture / Services / Scope

### Attic Binary Cache

- **Attic**: Self-hosted Nix binary cache server, served at `cache.racci.dev`.
- Storage is backed by the Storage Coordinator with zstd chunked/compressed NAR storage.
- The Attic database uses PostgreSQL on the Database Coordinator.
- Requires proof-of-possession for uploads, with a 14-day default garbage-collection retention period run on a schedule.

### Distributed Builds

As a `distributedBuilders` host, `nixserv` exposes the `builder` user over SSH.
Other hosts configure `nix.distributedBuilds` and connect to it as a remote build machine (`ssh-ng`) to offload Nix builds.

## Secrets

### Declared secrets

| Secret key                | Purpose                 |
| ------------------------- | ----------------------- |
| `ATTIC_ENVIRONMENT`       | Attic environment file  |
| `POSTGRES/ATTIC_PASSWORD` | Attic database password |

## Operational Notes / Assumptions

- The cache endpoint and the build daemon rely on the Storage Coordinator for object storage and the Database Coordinator for the metadata database.
- The Attic HTTP endpoint is served through the IO Coordinator reverse proxy.

## References

- [Attic](https://docs.attic.rs) — Nix binary cache server
- [Distributed Builds](../../modules/nixos/server/distributed_builds.md)
- [Database Coordinator](../../hosts/server/nixdb.md)
- [Storage Coordinator](../../hosts/server/nixstor.md)
- [IO Coordinator](../../hosts/server/nixio.md)
