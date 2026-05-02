## Context

The current storage mount module lives in `modules/nixos/server/storage/bucket.nix` and exposes `server.storage.bucketMounts` as an `attrsOf` submodule. That module hardcodes a MinIO+s3fs flow: it generates `S3FS_AUTH/<NAME>` sops secrets, installs `pkgs.s3fs`, and emits FUSE-backed `fileSystems` entries that always target `https://minio.racci.dev`.

At the same time, the repository now has a separate SeaweedFS deployment in `modules/nixos/server/storage/seaweedfs.nix`, but that module is evaluation-oriented and not part of the existing bucket-mount consumer path. The requested change merges these worlds at the mount abstraction layer: rename the current option to `server.storage.swfsMount`, let each mount choose a backend, use `weed mount` for SeaweedFS instead of the S3-compatible gateway, and add automated recovery for broken mounts.

This is a cross-cutting change because it affects the storage module, multiple service consumers, systemd unit generation, secret handling, and the storage documentation.

### Component Diagram

```text
server.storage.swfsMount.<name>
                |
                v
modules/nixos/server/storage/bucket.nix
                |
                +--> common option normalizer
                |      - mountLocation
                |      - uid/gid/umask
                |      - backend selector
                |      - health-check policy
                |
                +--> MinIO backend emitter
                |      - sops S3FS_AUTH/<NAME>
                |      - pkgs.s3fs
                |      - FUSE mount unit / fileSystems entry
                |
                +--> SeaweedFS backend emitter
                |      - weed mount service
                |      - filer address + filer path
                |      - SeaweedFS package / security config
                |
                +--> generated health-check service + timer
                |      - timeout-protected probe
                |      - lazy unmount on failure
                |      - backend-specific restart
                |
                +--> docs + consuming modules
                       - immich
                       - nextcloud
                       - prometheus
                       - loki
```

## Goals / Non-Goals

**Goals:**

- Replace `server.storage.bucketMounts` with a single renamed `server.storage.swfsMount` abstraction.
- Support backend selection per mount so existing MinIO-backed consumers and new SeaweedFS-backed consumers use one interface.
- Keep common ownership and mount-path controls while allowing backend-specific configuration.
- Use `weed mount` directly for SeaweedFS mounts, targeting filer addresses and filer paths rather than the SeaweedFS S3 endpoint.
- Add systemd-managed health-check and recovery behavior so stale or broken mounts can be remounted automatically.
- Update the repository’s existing server consumers and storage docs to the new option name and behavior.

**Non-Goals:**

- Preserving a compatibility alias for `server.storage.bucketMounts`.
- Replacing the existing SeaweedFS evaluation deployment or redesigning its proxy/Caddy surface.
- Solving multi-host SeaweedFS lock coordination, replication, erasure coding, or data migration in this change.
- Extending the abstraction to Home Manager or non-server hosts.

## Decisions

### Decision 1: Use a single discriminated mount submodule

**Choice:** Keep the existing `attrsOf` pattern but rename the option to `server.storage.swfsMount` and require each entry to declare `backend = "minio" | "seaweedfs"`.

Each entry will contain:

- common fields such as `mountLocation`, `uid`, `gid`, `umask`, and health-check settings
- backend-specific nested settings for either MinIO or SeaweedFS

This keeps the consumer surface centralized while making the backend distinction explicit.

**Rationale:** The current module is already consumed from several places (`immich`, `nextcloud`, `prometheus`, `loki`). A discriminated submodule keeps those consumers on one abstraction instead of forcing the repository to manage separate `bucketMounts` and `seaweedMounts` trees.

**Alternatives considered:**

- Keep `bucketMounts` and only add a backend field: rejected because the name becomes misleading once a mount is no longer bucket/S3-specific.
- Introduce separate `server.storage.minioMounts` and `server.storage.seaweedfsMounts`: rejected because it duplicates common ownership, path, and health-check behavior.

### Decision 2: Keep backend emitters separate behind the shared abstraction

**Choice:** The MinIO backend will continue to use the existing s3fs-based FUSE flow, while the SeaweedFS backend will generate a dedicated `weed mount` systemd service.

Expected backend model:

- **MinIO**: bucket name, credentials file, endpoint, and s3fs options
- **SeaweedFS**: filer address, filer path, optional security/config paths, and `weed mount` runtime flags

**Rationale:** The two backends do not have identical transport models. MinIO mounts are S3-compatible object mounts driven by s3fs, while SeaweedFS `weed mount` exposes a filer path and talks to SeaweedFS services directly. Trying to flatten both backends into the same low-level option set would either hide important backend mechanics or push invalid options onto the wrong backend.

**Alternatives considered:**

- Mount SeaweedFS through its S3-compatible gateway with s3fs: rejected because the user explicitly wants `weed mount`, and the upstream SeaweedFS guidance positions `weed mount` as the native filer-backed POSIX mount path.
- Convert both backends to a single generic shell-wrapper service model immediately: rejected because MinIO already has a working repository pattern through `fileSystems`, so only SeaweedFS needs a new runtime model.

### Decision 3: Add explicit health-check and recovery units instead of relying on restart policy alone

**Choice:** Generate a backend-aware health-check service and timer for each mount entry. The probe should use timeout-protected filesystem access against the mounted path and then trigger backend-specific remediation when the mount is stale.

Recovery sequence:

1. detect unhealthy mount state with `mountpoint`/`findmnt` plus a timeout-protected stat/read on the mount path
2. perform a lazy FUSE unmount (`fusermount -uz`) when needed
3. restart the corresponding mount unit or service

**Rationale:** External s3fs operational guidance shows that broken FUSE mounts often remain present but unusable, so `Restart=always` on its own is insufficient. A health-check service closes that gap and gives the abstraction a consistent recovery story across both backends.

**Alternatives considered:**

- Only use `Restart=always`: rejected because stale mounts can survive without the process exiting cleanly.
- Depend on manual remediation: rejected because the user has already seen high-IO failures requiring manual remounting.

### Decision 4: Keep secret handling backend-specific and reuse current conventions where possible

**Choice:** Preserve the current default MinIO secret convention (`S3FS_AUTH/<NAME>`) for MinIO entries, and introduce explicit SeaweedFS mount inputs for the security/config material needed by `weed mount`.

**Rationale:** The repository already has working secret defaults for s3fs. SeaweedFS is different: upstream `weed mount` reads filer/security settings from its own configuration model, so the mount abstraction should expose the paths it needs rather than pretending the MinIO credential file format applies to both.

**Alternatives considered:**

- Force both backends through one shared credential-file shape: rejected because the backends authenticate differently.

### Decision 5: Land the breaking rename and all in-repo consumer migrations together

**Choice:** Implement the option rename, module changes, consumer updates, and documentation updates in one cohesive change.

**Rationale:** Because `server.storage.bucketMounts` is intentionally being removed, partial rollout inside the repository would leave internal consumers broken. The change should be atomic at repository level even if deployment happens host by host.

## Risks / Trade-offs

**[Different runtime models per backend]** -> MinIO and SeaweedFS mounts will be implemented differently under the hood.  
*Mitigation:* Keep the common option surface small and explicit, and isolate backend-specific logic behind clearly separated emitters.

**[Health checks may flap under transient IO stalls]** -> An aggressive probe interval or short timeout could cause unnecessary remounts.  
*Mitigation:* Make timeout and interval configurable with conservative defaults, and keep recovery idempotent.

**[Lazy unmount can interrupt in-flight work]** -> `fusermount -uz` is pragmatic for broken FUSE mounts but may cut off operations already in progress.  
*Mitigation:* Use it only after a failed health probe, log the reason, and document the behavior as a recovery trade-off.

**[SeaweedFS mount configuration may diverge from the current evaluation deployment]** -> The mount abstraction could assume filer/security details that are not universally true outside the evaluation host.  
*Mitigation:* Require explicit filer/security inputs in the SeaweedFS backend instead of hardcoding evaluation-only defaults.

**[Requested name is singular while the option remains an attrset]** -> `swfsMount` is slightly less intuitive than `swfsMounts`.  
*Mitigation:* Preserve the user-requested name in the API and document that it remains an attribute set of named mount definitions.

## Migration Plan

1. Replace the current option definition in `bucket.nix` with the new `server.storage.swfsMount` schema.
2. Convert all current in-repo consumers to the new API with `backend = "minio"` and preserve their existing mount paths, ownership, and permissions.
3. Add SeaweedFS backend support through generated `weed mount` units and package/runtime wiring.
4. Add generated health-check services/timers and backend-specific remount actions.
5. Update storage documentation to describe the breaking rename, backend selection, and health-recovery behavior.
6. Validate affected host builds and `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"`.

**Rollback:** Revert the change as a unit. Because backward compatibility is intentionally not preserved, rollback is repository-level rather than per-option.

### Sequence Diagram: MinIO-backed mount

```text
consumer module -> server.storage.swfsMount.media: declare backend=minio
swfs mount module -> secret resolver: derive credentials file from S3FS_AUTH/MEDIA or explicit path
swfs mount module -> system config: install s3fs and generate mount unit/fileSystems entry
systemd -> s3fs: mount bucket from MinIO endpoint to mountLocation
health timer -> check service: probe mount health on interval
check service -> systemd: restart mount unit if probe fails
```

### Sequence Diagram: SeaweedFS-backed mount

```text
consumer module -> server.storage.swfsMount.archive: declare backend=seaweedfs
swfs mount module -> seaweed backend emitter: build weed mount command from filer address, filer path, and security config
seaweed backend emitter -> systemd: create weed-mount service for mountLocation
systemd -> weed mount: attach filer path to local mountpoint
health timer -> check service: probe mount health on interval
check service -> fusermount: lazily detach stale FUSE mount
check service -> systemd: restart weed-mount service
```

## Open Questions

1. What default probe interval and timeout should be used before maintainers tune them per mount?
2. Which SeaweedFS mount flags should be exposed directly in the first version versus left in an `extraArgs` escape hatch?
3. Should the MinIO backend also move fully to explicit systemd services in a later follow-up for backend parity, or is the existing `fileSystems` pattern sufficient once health checks are added?
