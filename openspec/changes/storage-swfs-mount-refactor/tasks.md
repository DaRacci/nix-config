## 1. Rename and reshape the storage mount module

- [x] 1.1 Replace the `server.storage.bucketMounts` option in `modules/nixos/server/storage/bucket.nix` with the new `server.storage.swfsMount` attrs-of-submodule interface
- [x] 1.2 Add the common mount fields and backend selector required by the new `server.storage.swfsMount.<name>` schema, including per-mount health-check settings
- [x] 1.3 Remove the repository-local `server.storage.bucketMounts` implementation path so only the new abstraction remains

## 2. Implement backend-specific mount generation

- [x] 2.1 Keep MinIO-backed entries working by mapping `backend = "minio"` mounts to the current s3fs-based mount flow with the new schema
- [x] 2.2 Add SeaweedFS-backed entries that generate `weed mount` systemd services from filer address, filer path, and runtime/security inputs
- [x] 2.3 Validate backend-specific options so MinIO-only and SeaweedFS-only settings are required only for the selected backend

## 3. Add automated mount recovery

- [x] 3.1 Generate bounded mount health-check logic for each `server.storage.swfsMount` entry using systemd-managed services and timers or equivalent unit wiring
- [x] 3.2 Implement backend-aware recovery that lazily detaches stale FUSE mounts and restarts the corresponding s3fs mount unit or `weed mount` service
- [x] 3.3 Expose mount-level configuration for enabling recovery and controlling probe cadence/timeouts with conservative defaults

## 4. Migrate in-repo consumers and docs

- [x] 4.1 Migrate existing in-repo consumers in `hosts/server/nixcloud/immich.nix`, `hosts/server/nixcloud/nextcloud.nix`, `modules/nixos/server/monitoring/collector/prometheus.nix`, and `modules/nixos/server/monitoring/collector/loki.nix` to `server.storage.swfsMount` with `backend = "minio"`
- [x] 4.2 Update `docs/src/modules/nixos/server/storage.md` and any related storage documentation to describe the rename, backend selection, and health-recovery behavior
- [x] 4.3 Ensure documentation continues to reference the existing SeaweedFS evaluation page accurately without implying that the evaluation deployment itself was replaced

## 5. Verification

- [x] 5.1 Run `nix fmt .` after the Nix and documentation changes
- [x] 5.2 Build the affected NixOS configurations that currently consume storage mounts and confirm the renamed interface evaluates successfully
- [x] 5.3 Run `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` and confirm the refactor does not introduce unrelated regressions
