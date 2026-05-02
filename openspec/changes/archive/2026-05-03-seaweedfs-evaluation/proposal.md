## Why

The repository needs an S3-compatible storage option to evaluate after MinIO's upstream abandonment, but existing MinIO-backed workloads must remain untouched during that decision period. A parallel SeaweedFS deployment is needed now so the repository can evaluate a candidate replacement on the IO primary host without migration work, scope creep, or disruption to current mounts.

## What Changes

- Add SeaweedFS evaluation support under the server storage module area and import it through the storage module set.
- Configure an all-in-one SeaweedFS deployment on the IO primary host only, using the repository's `server.ioPrimaryHost` role as the source of truth.
- Expose the SeaweedFS evaluation endpoints through Caddy, including the S3-compatible endpoint and the additional component endpoints needed for evaluation.
- Add separate sops-managed SeaweedFS mTLS and JWT material for evaluation use without touching MinIO secrets.
- Add documentation that describes evaluation scope, host gating, the SeaweedFS proxy surface, and security material expectations.

## Non-goals

- Replacing MinIO, migrating data, or modifying existing s3fs mounts.
- Adding multi-node SeaweedFS topology, replication, erasure coding, or WebDAV.
- Introducing a repository-local `server.storage.seaweedfs.*` option tree before the current evaluation module shape is proven out.
- Reworking unrelated storage services or host architecture.

## Capabilities

### New Capabilities

- `seaweedfs-storage-module`: Define the repository-local SeaweedFS evaluation module and storage import wiring.
- `seaweedfs-io-primary-deployment`: Run SeaweedFS evaluation services only on the host selected by `server.ioPrimaryHost`.
- `seaweedfs-s3-proxy`: Expose the SeaweedFS evaluation endpoints through Caddy, including S3 and the component endpoints needed for the evaluation deployment.
- `seaweedfs-evaluation-secrets`: Provide separate sops-managed mTLS and JWT material for SeaweedFS evaluation without altering MinIO secrets.
- `seaweedfs-evaluation-documentation`: Document evaluation scope, endpoint behavior, and operating constraints.

### Modified Capabilities

None.

## Impact

- Affected code: `modules/nixos/server/storage/`, the IO-primary host wiring, relevant `secrets.yaml` files, and the current server storage documentation files under `docs/src/modules/nixos/server/`.
- Affected systems: the server selected by `server.ioPrimaryHost`, the Caddy proxy layer for SeaweedFS evaluation endpoints, and SOPS-managed evaluation security material.
- Affected configurations: the IO primary server host only; no Home Manager configurations are in scope.
- External dependencies: the upstream SeaweedFS package or imported module surface, Caddy reverse proxy behavior, and sops-managed TLS/JWT material for the evaluation deployment.
