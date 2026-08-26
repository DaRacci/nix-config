# nixstor - Storage

## Purpose

NixStor is the storage primary host.

## Entry Point

- **Main file**: [`hosts/server/nixstor/default.nix`](../../../../hosts/server/nixstor/default.nix)
- **Supporting files**: [`modules/nixos/server/storage/seaweedfs.nix`](../../../../modules/nixos/server/storage/seaweedfs.nix)

## Architecture / Services / Scope

### SeaweedFS Evaluation

- SeaweedFS master, volume, filer, S3 endpoint, admin UI, and worker components
- mTLS between Caddy and SeaweedFS components using SOPS-managed certificates
- JWT-based inter-component authentication inside SeaweedFS

See [SeaweedFS](../../modules/nixos/server/storage/seaweedfs.md) for full details.

## Secrets

### Declared secrets

| Secret                        | Purpose                                |
| ----------------------------- | -------------------------------------- |
| `MINIO_ROOT_CREDENTIALS`      | MinIO root access key and secret       |
| `SEAWEEDFS/JWT/MASTER`        | JWT signing key for SeaweedFS master   |
| `SEAWEEDFS/JWT/MASTER_READ`   | JWT read-only key for SeaweedFS master |
| `SEAWEEDFS/JWT/FILER`         | JWT signing key for SeaweedFS filer    |
| `SEAWEEDFS/JWT/FILER_READ`    | JWT read-only key for SeaweedFS filer  |
| `SEAWEEDFS/TLS/CA`            | SeaweedFS mTLS CA certificate          |
| `SEAWEEDFS/TLS/<SERVICE>_CRT` | Per-component mTLS certificate         |
| `SEAWEEDFS/TLS/<SERVICE>_KEY` | Per-component mTLS private key         |

The SeaweedFS TLS secrets cover six services: `MASTER`, `VOLUME`, `FILER`, `CLIENT`, `ADMIN`, and `WORKER`.

## Operational Notes / Assumptions

- SeaweedFS services wait for `network-online.target` before starting, so early-boot network readiness is a hard prerequisite.
- SeaweedFS components run under the dedicated `seaweedfs` service user and group; file ownership and secret permissions assume that account exists.
- Shared component services are configured with `Restart = "always"`, so repeated restart loops usually indicate an unmet dependency rather than one-shot startup failure.
- Internal gRPC and proxy-facing TLS rely on the `SEAWEEDFS/TLS/*` certificate set, including the CA bundle; both Caddy and SeaweedFS verify that CA during mTLS connections.

## References

- [Storage Module](../../modules/nixos/server/storage.md)
- [SeaweedFS Evaluation](../../modules/nixos/server/storage/seaweedfs.md)
- [Proxy Module](../../modules/nixos/server/proxy.md)
- [IO Coordinator](../../hosts/server/nixio.md)
