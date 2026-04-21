## Why

The repository needs an S3-compatible storage option to evaluate after MinIO's upstream abandonment, but existing MinIO-backed workloads must remain untouched during that decision period. A parallel SeaweedFS deployment is needed now so the repository can evaluate a candidate replacement on the IO primary host without migration work, scope creep, or disruption to current mounts.

## What Changes

- Add SeaweedFS evaluation support under the server storage module area and import it through the storage module set.
- Configure an all-in-one SeaweedFS deployment on the IO primary host only, using the repository's `server.ioPrimaryHost` role as the source of truth.
- Expose only the SeaweedFS S3-compatible endpoint through Caddy with TLS termination at the proxy.
- Add separate sops-managed SeaweedFS credentials or policy configuration for evaluation use.
- Add documentation that describes evaluation scope, host gating, S3 endpoint exposure, and secret expectations.

## Non-goals

- Replacing MinIO, migrating data, or modifying existing s3fs mounts.
- Adding multi-node SeaweedFS topology, replication, erasure coding, or WebDAV.
- Exposing SeaweedFS internal gRPC or filer ports through the proxy.
- Reworking unrelated storage services or host architecture.

## Capabilities

### New Capabilities
- `seaweedfs-storage-module`: Define the repository-local SeaweedFS evaluation module and storage import wiring.
- `seaweedfs-io-primary-deployment`: Run SeaweedFS evaluation services only on the host selected by `server.ioPrimaryHost`.
- `seaweedfs-s3-proxy`: Expose only the S3-compatible SeaweedFS endpoint through Caddy with proxy-safe forwarding behavior.
- `seaweedfs-evaluation-secrets`: Provide separate sops-managed credentials or S3 configuration for SeaweedFS evaluation.
- `seaweedfs-evaluation-documentation`: Document evaluation scope, endpoint behavior, and operating constraints.

### Modified Capabilities

None.

## Impact

- Affected code: `modules/nixos/server/storage/`, the IO-primary host wiring, relevant `secrets.yaml` files, and `docs/src/components/`.
- Affected systems: the server selected by `server.ioPrimaryHost`, the Caddy proxy path for the SeaweedFS S3 endpoint, and SOPS-managed evaluation secrets.
- Affected configurations: the IO primary server host only; no Home Manager configurations are in scope.
- External dependencies: the upstream SeaweedFS package or imported module surface, Caddy reverse proxy behavior, and sops-managed JSON configuration for S3 identities or policies.
