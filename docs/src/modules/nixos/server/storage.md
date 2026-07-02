# Server Storage — Mount Abstractions and Storage Services

## Purpose

The storage module manages persistent storage abstractions for the server fleet. Today that includes the `server.storage.swfsMount` mount abstraction and an evaluation-only SeaweedFS deployment. This area provides:

- declarative MinIO-backed and SeaweedFS-backed mounts through `server.storage.swfsMount`
- a SeaweedFS evaluation deployment on the storage primary host

## Entry Point

- **Main file**: `modules/nixos/server/storage/default.nix`
- **Supporting file**: `modules/nixos/server/storage/bucket.nix`
- **Supporting file**: `modules/nixos/server/storage/seaweedfs.nix`

## Architecture / Services / Scope

### swfsMount

The `swfsMount` option is the repository's declarative storage mount interface. It is a breaking rename from `server.storage.bucketMounts` and each entry chooses a backend explicitly.

- **Backend Selection**: Set `backend = "minio"` to mount a MinIO bucket through `s3fs`, or `backend = "seaweedfs"` to mount a SeaweedFS filer path through `weed mount`.
- **Use Scope**: Use `swfsMount` for bucket/object-style workloads or external filer mounts. Do not point it at app state that expects normal local filesystem semantics, frequent metadata updates, or permission changes.
- **Common Mount Controls**: Each entry supports `mountLocation`, `uid`, `gid`, `umask`, and `requiredByServices` so consuming services can wait for the generated mount unit.
- **Health Recovery**: Each entry also supports `healthCheck.*` options. By default the module generates a timer-driven probe that can lazily unmount stale FUSE mounts, restart the mount service, and optionally restart dependent services.

#### MinIO backend

- **Credential Management**: By default the MinIO backend provisions and uses sops secrets with the pattern `S3FS_AUTH/<NAME_IN_UPPERCASE>`. These secrets must contain `ACCESS_KEY_ID:SECRET_ACCESS_KEY`.
- **Runtime Model**: MinIO mounts now run as generated systemd services instead of `fileSystems` entries so they can share the same recovery model as SeaweedFS.

#### SeaweedFS backend

- **Mount Command**: SeaweedFS mounts use `weed mount` directly against a filer endpoint and filer path.
- **Runtime Inputs**: Configure the SeaweedFS backend through `seaweedfs.filer`, `seaweedfs.filerPath`, and optional runtime flags such as UID/GID mapping or write-buffer limits.

### SeaweedFS Evaluation

SeaweedFS is documented separately because it is not part of the current software filesystem workflow. The repository uses it as an evaluation deployment gated by `server.storagePrimaryHost` — SeaweedFS services and their Caddy proxy rules only activate on the host designated as the storage primary. The `swfsMount` mount module itself remains role-agnostic; host placement is determined by which host runs the services.

MinIO services also live on the storage primary host. The MinIO endpoint presented to mounts is served through the IO Coordinator reverse proxy, which routes to the MinIO instance on whichever host currently holds the storage primary role.

See [SeaweedFS Evaluation](storage/seaweedfs.md) for details on scope, host gating, proxy behavior, and security material.

## Secrets

- `S3FS_AUTH/<NAME_IN_UPPERCASE>`: MinIO backend credentials, containing `ACCESS_KEY_ID:SECRET_ACCESS_KEY`.

## Operational Notes / Assumptions

- **FUSE Access**: The module enables `programs.fuse.userAllowOther = true` whenever mounts are defined so both `s3fs` and `weed mount` can expose shared FUSE mounts safely.
- **Network Dependency**: Generated mount services depend on `network-online.target` before attempting either backend.
- **Recovery Behavior**: The health-check timer uses `mountpoint` plus a bounded `stat` probe. On failure it lazily unmounts the path, restarts the generated mount service, and can restart configured dependent services.
- **SeaweedFS Scope**: The SeaweedFS evaluation deployment remains separate from this abstraction. The new SeaweedFS backend only reuses `weed mount` for workload mounts and does not replace the evaluation stack.

## References

- [s3fs-fuse Repository](https://github.com/s3fs-fuse/s3fs-fuse)

- [SeaweedFS Evaluation](storage/seaweedfs.md)

- IO Coordinator(../../../hosts/server/nixio.md)
