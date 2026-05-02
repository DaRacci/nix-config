# Storage

The storage module manages persistent storage abstractions for the server fleet. Today that includes the `server.storage.swfsMount` mount abstraction and an evaluation-only SeaweedFS deployment.

## Purpose

This area provides:

- declarative MinIO-backed and SeaweedFS-backed mounts through `server.storage.swfsMount`
- a SeaweedFS evaluation deployment on the IO primary host

## Key Options and Behaviors

### swfsMount

The `swfsMount` option is the repository's declarative storage mount interface. It is a breaking rename from `server.storage.bucketMounts` and each entry chooses a backend explicitly.

- **Backend Selection**: Set `backend = "minio"` to mount a MinIO bucket through `s3fs`, or `backend = "seaweedfs"` to mount a SeaweedFS filer path through `weed mount`.
- **Common Mount Controls**: Each entry supports `mountLocation`, `uid`, `gid`, `umask`, and `requiredByServices` so consuming services can wait for the generated mount unit.
- **Health Recovery**: Each entry also supports `healthCheck.*` options. By default the module generates a timer-driven probe that can lazily unmount stale FUSE mounts, restart the mount service, and optionally restart dependent services.

#### MinIO backend

- **Credential Management**: By default the MinIO backend provisions and uses sops secrets with the pattern `S3FS_AUTH/<NAME_IN_UPPERCASE>`. These secrets must contain `ACCESS_KEY_ID:SECRET_ACCESS_KEY`.
- **Runtime Model**: MinIO mounts now run as generated systemd services instead of `fileSystems` entries so they can share the same recovery model as SeaweedFS.

#### SeaweedFS backend

- **Mount Command**: SeaweedFS mounts use `weed mount` directly against a filer endpoint and filer path.
- **Runtime Inputs**: Configure the SeaweedFS backend through `seaweedfs.filer`, `seaweedfs.filerPath`, and optional runtime flags such as UID/GID mapping or write-buffer limits.

### SeaweedFS Evaluation

SeaweedFS is documented separately because it is not part of the current bucket-mount workflow. The repository uses it as an evaluation deployment that runs alongside MinIO on the IO primary host and exposes its endpoint set through the existing Caddy proxy integration.

See [SeaweedFS Evaluation](storage/seaweedfs.md) for details on scope, host gating, proxy behavior, and security material.

#### Example

The following example mounts a MinIO-backed `media` bucket and sets specific ownership.

```nix
{
  server.storage.swfsMount.media = {
    backend = "minio";
    uid = 1000;
    gid = 1000;
    umask = 007;
  };
}
```

## Operational Notes

- **FUSE Access**: The module enables `programs.fuse.userAllowOther = true` whenever mounts are defined so both `s3fs` and `weed mount` can expose shared FUSE mounts safely.
- **Network Dependency**: Generated mount services depend on `network-online.target` before attempting either backend.
- **MinIO Endpoint**: The MinIO backend defaults to `https://minio.racci.dev` unless a mount overrides the endpoint explicitly.
- **Recovery Behavior**: The health-check timer uses `mountpoint` plus a bounded `stat` probe. On failure it lazily unmounts the path, restarts the generated mount service, and can restart configured dependent services.
- **SeaweedFS Scope**: The SeaweedFS evaluation deployment remains separate from this abstraction. The new SeaweedFS backend only reuses `weed mount` for workload mounts and does not replace the evaluation stack.

## References

- [s3fs-fuse Repository](https://github.com/s3fs-fuse/s3fs-fuse)
- [SeaweedFS Evaluation](storage/seaweedfs.md)
