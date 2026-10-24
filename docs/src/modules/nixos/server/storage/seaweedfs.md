# SeaweedFS Evaluation — Evaluation-Only Storage Service

## Purpose

SeaweedFS is deployed here as an evaluation-only storage service alongside MinIO. It exists to validate SeaweedFS as a possible replacement candidate without changing existing MinIO-backed workloads or the repository's migration posture. The evaluation deployment provides an all-in-one SeaweedFS stack on the storage primary host so the repository can test endpoint shape, proxy integration, and service behaviour in a realistic environment while keeping the current MinIO setup intact.

## Entry Point

- **Main file**: `modules/nixos/server/storage/seaweedfs.nix`
- **Supporting file**: `modules/nixos/server/storage/default.nix`

## Architecture / Services / Scope

- **Evaluation only**: this deployment does not replace MinIO and does not perform any migration.
- **Storage primary only**: the module is gated by `config.server.storagePrimaryHost == config.networking.hostName`.
- **All-in-one topology**: the evaluation enables the SeaweedFS master, volume, filer, S3 endpoint, admin UI, and worker components on the coordinator host.
- **Proxy surface**: endpoints are exposed through the existing `server.proxy.virtualHosts` integration instead of host-local Caddy configuration. Current surface includes the master, filer, S3-compatible, volume, and admin endpoints under the `seaweedfs.${server.proxy.domain}` subtree. Client-facing TLS terminates at Caddy; gRPC-backed component endpoints additionally get the backend transport settings required for SeaweedFS communication.
- **Option surface**: the module uses the upstream `services.seaweedfs` option surface rather than introducing a repository-local `server.storage.seaweedfs.*` option tree.

## Secrets

SeaweedFS SOPS entries are separate from MinIO secrets and are used for:

- **mTLS between Caddy and SeaweedFS components**
- **JWT-based inter-component authentication inside SeaweedFS**

These entries live under the `SEAWEEDFS` secret tree on the storage primary host and include both JWT material and TLS certificates/keys for the SeaweedFS component set.

### TLS trust chain

SeaweedFS TLS material uses the shared offline `Fleet mTLS Root CA` and a dedicated `SeaweedFS Intermediate CA`:

```text
Fleet mTLS Root CA
└── SeaweedFS Intermediate CA
    └── master, volume, filer, admin, client, worker leaves
```

`SEAWEEDFS/TLS/CA` is a PEM trust bundle.
It contains the original flat `SeaweedFS CA` and the `Fleet mTLS Root CA` until the first Fleet rollout completes, because the currently deployed leaves may still be signed by the original CA.
After all components run the Fleet chains, reduce it to the Fleet root only.
TLS material is stored as binary SOPS files under `hosts/server/nixio/seaweedfs-tls/`: `CA`, `<SERVICE>_CRT`, and `<SERVICE>_KEY`.
Each `SEAWEEDFS/TLS/<SERVICE>_CRT` value is a chain ordered leaf first, then the SeaweedFS intermediate.
Leaves use both `serverAuth` and `clientAuth` because the same component certificate is used as a gRPC server and client certificate.
The root and intermediate private keys are kept offline.

The CA hierarchy, key custody, issuance, and rotation are documented in [Internal mTLS CA](../../../../security/internal_mtls_ca.md).
Component SANs must match the Caddy `tls_server_name` values: `seaweedfs.${server.proxy.domain}` for the master, and `<service>.seaweedfs.${server.proxy.domain}` for volume, filer, and admin.
`server.proxy.domain` is the configured proxy domain.

## Operational Notes / Assumptions

- The evaluation deployment is separate from `server.storage.swfsMount`. The storage abstraction can use `weed mount` for SeaweedFS-backed workload mounts without changing the evaluation topology described here.
- This deployment is intended to shake out integration details first; repository-local abstractions can be added later if SeaweedFS proves to be a good fit.

## References

- [Storage Overview](../storage.md)
- [SeaweedFS upstream repository](https://github.com/seaweedfs/seaweedfs)
