# Storage Integration Tests

## Scope

MinIO object storage on nixio, s3fs FUSE mounts for service data directories (nextcloud, immich, loki), SeaweedFS migration path, docker registry S3 backend.

## Unit Tests (via `server.tests.units`)

### MinIO (nixio)
```nix
server.tests.units.minio = {
  testScript = { config, ... }: ''
    # Health endpoint
    out = ${config.host.name}.succeed("curl -sf http://localhost:9000/minio/health/live")
    assert out.strip() == "OK", "minio health check failed"

    # Cluster readiness
    out = ${config.host.name}.succeed("curl -sf http://localhost:9000/minio/health/cluster")
    assert out.strip() == "OK", "minio cluster health failed"

    # Console port
    ${config.host.name}.wait_for_open_port(9001)
  '';
};
```

### SeaweedFS Master (nixio, Phase 2)
```nix
server.tests.units.seaweedfs-master = {
  testScript = { config, ... }: ''
    ${config.host.name}.wait_for_open_port(9333)
    out = ${config.host.name}.succeed("curl -sf http://localhost:9333/cluster/status")
    assert "topology" in out, "seaweedfs master not responding"
  '';
};
```

### SeaweedFS Volume (nixio, Phase 2)
```nix
server.tests.units.seaweedfs-volume = {
  testScript = { config, ... }: ''
    ${config.host.name}.wait_for_open_port(8080)
    out = ${config.host.name}.succeed("curl -sf http://localhost:8080/status")
    assert "Volume" in out, "seaweedfs volume not responding"
  '';
};
```

### SeaweedFS Filer (nixio, Phase 2)
```nix
server.tests.units.seaweedfs-filer = {
  testScript = { config, ... }: ''
    ${config.host.name}.wait_for_open_port(8888)
    ${config.host.name}.succeed("curl -sf http://localhost:8888/")
  '';
};
```

### Storage Mounts (nixio, Phase 2)
```nix
server.tests.units.storage-mounts = {
  testScript = { config, ... }: ''
    # Check each mounted location exists and is a mountpoint
    # These are s3fs FUSE mounts backed by minio
    for mount in ["/var/lib/nextcloud/data", "/var/lib/immich", "/var/lib/loki"]:
      ${config.host.name}.succeed(f"mountpoint -q {mount}")
      ${config.host.name}.succeed(f"touch {mount}/.test-writable && rm {mount}/.test-writable")

    # Health check timers should be active
    for timer in ["swfs-mount-health-nextcloud.timer", "swfs-mount-health-immich.timer"]:
      ${config.host.name}.succeed(f"systemctl is-active {timer}")
  '';
};
```

### Docker Registry (nixdev)
```nix
server.tests.units.docker-registry-storage = {
  testScript = { config, ... }: ''
    # Registry v2 API
    out = ${config.host.name}.succeed("curl -sf http://localhost:${toString config.services.dockerRegistry.port}/v2/")
    assert "{}" in out, "docker registry not returning v2 API"
  '';
};
```

## Scenario Tests

### `storage-mount` (Phase 2)
- **Host**: nixio
- **Assert**: FUSE mount services start, directories writable, health timers active
- This lives as both a unit test (above) and a scenario for multi-host storage interactions

## Storage Migration Path

Current: MinIO backed s3fs mounts (nextcloud, immich, loki)
Target: SeaweedFS native mounts

- Both backends co-exist via `server.storage.swfsMount.<name>.backend`
- Unit tests cover both paths
- Migration scenario (Phase 3): Write to s3fs mount → read via SeaweedFS mount

## Untestable

- Actual S3 bucket creation (MinIO creates buckets on first-write)
- Cross-host s3fs mount (mounts are local to nixio only)
- SeaweedFS peer discovery (peers set to `"none"` in config)
- Real S3 credentials (deterministic test secrets used)
- MinIO bucket data persistence across reboots (VM is ephemeral)
