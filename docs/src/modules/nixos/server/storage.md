# Storage

The storage module manages persistent storage abstractions for the server fleet. Today that includes both the established MinIO-backed bucket mount flow and an evaluation-only SeaweedFS deployment.

## Purpose

This area provides:

- declarative MinIO-backed bucket mounts through `server.storage.bucketMounts`
- a SeaweedFS evaluation deployment on the IO primary host

## Key Options and Behaviors

### Bucket Mounts

The `bucketMounts` option uses `s3fs-fuse` to mount buckets from `https://minio.racci.dev`.

- **Credential Management**: It automatically looks for sops secrets with the pattern `S3FS_AUTH/<NAME_IN_UPPERCASE>`. These secrets should contain the credentials in the `ACCESS_KEY_ID:SECRET_ACCESS_KEY` format.
- **Mount Points**: Buckets are mounted at `/mnt/buckets/<bucket-name>` unless a different `mountLocation` is specified.
- **Ownership and Permissions**: You can control the mount ownership using `uid` and `gid`. The `umask` option (defaulting to `022`) controls the default file and directory permissions.

### SeaweedFS Evaluation

SeaweedFS is documented separately because it is not part of the current bucket-mount workflow. The repository uses it as an evaluation deployment that runs alongside MinIO on the IO primary host and exposes its endpoint set through the existing Caddy proxy integration.

See [SeaweedFS Evaluation](storage/seaweedfs.md) for details on scope, host gating, proxy behavior, and security material.

#### Example

The following example mounts a "media" bucket and sets specific ownership.

```nix
{
  server.storage.bucketMounts.media = {
    uid = 1000;
    gid = 1000;
    umask = 007;
  };
}
```

## Operational Notes

- **s3fs-fuse**: This module uses the `s3fs` package. It relies on FUSE, so it requires `programs.fuse.userAllowOther = true` which the module enables automatically when mounts are defined.
- **Network Dependency**: Mounts use the `_netdev` option to ensure they are only attempted after the network is up.
- **Credential Format**: Ensure that your sops secrets provide the exact string format required by s3fs.
- **MinIO Endpoint**: The module is currently configured to use `https://minio.racci.dev`.
- **SeaweedFS Scope**: The SeaweedFS deployment is evaluation-only and does not replace or migrate existing MinIO-backed workloads.

## References

- [s3fs-fuse Repository](https://github.com/s3fs-fuse/s3fs-fuse)
- [SeaweedFS Evaluation](storage/seaweedfs.md)
