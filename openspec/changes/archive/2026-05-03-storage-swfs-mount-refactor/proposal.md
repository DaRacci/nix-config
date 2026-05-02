## Why

The current `server.storage.bucketMounts` module hardcodes a MinIO+s3fs flow, while the repository now also has an independent SeaweedFS deployment path. The storage mount abstraction needs to be redesigned now so workloads can choose either MinIO or SeaweedFS declaratively, adopt `weed mount` for SeaweedFS, and recover automatically from the mount failures that have been observed under high IO load.

## What Changes

- **BREAKING** Rename `server.storage.bucketMounts` to `server.storage.swfsMount` and replace the current MinIO-only schema with a backend-selectable mount definition.
- Add backend-specific configuration so a mount can choose MinIO or SeaweedFS and provide the credentials, filer path, mount path, ownership, and runtime options required by that backend.
- Add SeaweedFS-backed mounts that use `weed mount` against the filer path instead of the S3-compatible gateway flow.
- Add systemd-managed mount supervision and a health-check/remount path for mount definitions so broken mounts can be detected and recovered without manual intervention.
- Update all in-repo consumers and storage documentation to the new option name and behavior.

## Non-goals

- Preserving backward compatibility with `server.storage.bucketMounts`.
- Replacing or redesigning the existing SeaweedFS evaluation deployment outside the mount-consumer integration needed for `weed mount`.
- Migrating existing bucket contents or changing unrelated MinIO, Caddy, or application service architecture.
- Introducing Home Manager storage abstractions.

## Capabilities

### New Capabilities

- `swfs-mount-abstraction`: Define the renamed `server.storage.swfsMount` interface, backend selection, and consumer-facing mount behavior.
- `swfs-mount-backends`: Specify how MinIO-backed mounts continue to use s3fs and how SeaweedFS-backed mounts use `weed mount` with backend-specific settings.
- `swfs-mount-health-recovery`: Detect broken mounts and restore them through systemd-managed health-check and remount behavior.
- `swfs-mount-documentation`: Document the breaking rename, backend schema, and operating model for resilient mounts.

### Modified Capabilities

None.

## Impact

- Affected code: `modules/nixos/server/storage/bucket.nix`, `modules/nixos/server/storage/default.nix` if import naming changes are needed, mount consumers in `hosts/server/nixcloud/immich.nix`, `hosts/server/nixcloud/nextcloud.nix`, `modules/nixos/server/monitoring/collector/prometheus.nix`, and `modules/nixos/server/monitoring/collector/loki.nix`.
- Affected documentation: `docs/src/modules/nixos/server/storage.md` and any storage-module pages that reference the current bucket-mount flow.
- Affected systems: NixOS server configurations that currently consume `server.storage.bucketMounts`, especially the nixcloud workloads and monitoring collectors; no Home Manager configurations are in scope.
- External dependencies: `s3fs-fuse`, `weed mount` from SeaweedFS, systemd mount/service/timer behavior, and existing sops-managed secret material for MinIO and SeaweedFS.
