# SeaweedFS Evaluation — Evaluation-Only Storage Service

## Purpose

SeaweedFS is deployed here as an evaluation-only storage service alongside MinIO. It exists to validate SeaweedFS as a possible replacement candidate without changing existing MinIO-backed workloads or the repository's migration posture. The evaluation deployment provides an all-in-one SeaweedFS stack on the storage primary host so the repository can test endpoint shape, proxy integration, and service behavior in a realistic environment while keeping the current MinIO setup intact.

## Entry Point

- **Main file**: `modules/nixos/server/storage/seaweedfs.nix`
- **Supporting file**: `modules/nixos/server/storage/default.nix`

## Architecture / Services / Scope

- **Evaluation only**: this deployment does not replace MinIO and does not perform any migration.
- **Storage primary only**: the module is gated by `config.server.storagePrimaryHost == config.networking.hostName`.
- **All-in-one topology**: the evaluation enables the SeaweedFS master, volume, filer, S3 endpoint, admin UI, and worker components on the coordinator host.
- **Proxy surface**: endpoints are exposed through the existing `server.proxy.virtualHosts` integration instead of host-local Caddy configuration. Current surface includes the master, filer, S3-compatible, volume, and admin endpoints under the `seaweedfs.<domain>` subtree. Client-facing TLS terminates at Caddy; gRPC-backed component endpoints additionally get the backend transport settings required for SeaweedFS communication.
- **Option surface**: the module uses the upstream `services.seaweedfs` option surface rather than introducing a repository-local `server.storage.seaweedfs.*` option tree.

## Secrets

SeaweedFS SOPS entries are separate from MinIO secrets and are used for:

- **mTLS between Caddy and SeaweedFS components**
- **JWT-based inter-component authentication inside SeaweedFS**

These entries live under the `SEAWEEDFS` secret tree on the storage primary host and include both JWT material and TLS certificates/keys for the SeaweedFS component set.

## Operational Notes / Assumptions

- The evaluation deployment is separate from `server.storage.swfsMount`. The storage abstraction can use `weed mount` for SeaweedFS-backed workload mounts without changing the evaluation topology described here.
- This deployment is intended to shake out integration details first; repository-local abstractions can be added later if SeaweedFS proves to be a good fit.

## References

- [Storage Overview](../storage.md)
- [SeaweedFS upstream repository](https://github.com/seaweedfs/seaweedfs)
