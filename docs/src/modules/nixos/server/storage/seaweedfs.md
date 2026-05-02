# SeaweedFS Evaluation

SeaweedFS is currently deployed here as an evaluation-only storage service alongside MinIO. It exists to validate SeaweedFS as a possible S3-compatible replacement candidate without changing existing MinIO-backed workloads, bucket mounts, or migration flows.

## Purpose

The evaluation deployment provides an all-in-one SeaweedFS stack on the IO primary host so the repository can test endpoint shape, proxy integration, and service behavior in a realistic environment while keeping the current MinIO setup intact.

## Entry Points

- `modules/nixos/server/storage/seaweedfs.nix`
- `modules/nixos/server/storage/default.nix`

## Deployment Scope

- **Evaluation only**: this deployment does not replace MinIO and does not perform any migration.
- **IO primary only**: the module is gated by `config.server.ioPrimaryHost == config.networking.hostName`.
- **All-in-one topology**: the evaluation enables the SeaweedFS master, volume, filer, S3 endpoint, admin UI, and worker components on the coordinator host.

## Proxy Surface

The SeaweedFS evaluation endpoints are exposed through the existing `server.proxy.virtualHosts` integration instead of host-local Caddy configuration.

Current proxy surface includes:

- `seaweedfs.<domain>` for the master endpoint
- `filer.seaweedfs.<domain>` for the filer endpoint
- `s3.seaweedfs.<domain>` for the S3-compatible endpoint
- `volume.seaweedfs.<domain>` for the volume endpoint
- `admin.seaweedfs.<domain>` for the admin endpoint

Client-facing TLS terminates at Caddy. For gRPC-backed component endpoints, the proxy is additionally configured with the backend transport settings required for SeaweedFS communication.

## Security Material

The SeaweedFS SOPS entries are separate from MinIO secrets and are used for:

- **mTLS between Caddy and SeaweedFS components**
- **JWT-based inter-component authentication inside SeaweedFS**

These entries live under the `SEAWEEDFS` secret tree on the IO primary host and include both JWT material and TLS certificates/keys for the SeaweedFS component set.

## Operational Notes

- The SeaweedFS module uses the upstream `services.seaweedfs` option surface rather than introducing a repository-local `server.storage.seaweedfs.*` option tree.
- Existing `server.storage.bucketMounts` and MinIO configuration remain the active path for current workloads.
- This deployment is intended to shake out integration details first; repository-local abstractions can be added later if SeaweedFS proves to be a good fit.

## References

- [Storage Overview](../storage.md)
- [SeaweedFS upstream repository](https://github.com/seaweedfs/seaweedfs)
