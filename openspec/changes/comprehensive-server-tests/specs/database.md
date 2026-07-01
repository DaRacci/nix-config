# Database Integration Tests

## Scope

PostgreSQL, Redis, and pgadmin across the fleet. Covers local connect, remote connect, auth, and basic query execution.

## Unit Tests (via `server.tests.units`)

### Postgres Local (nixio)
```nix
server.tests.units.postgres-connect = {
  testScript = { config, ... }: ''
    # pg_isready checks both socket and TCP
    out = ${config.host.name}.succeed("pg_isready -h localhost -p ${toString config.services.postgresql.settings.port}")
    assert "accepting connections" in out, f"pg_isready failed: {out}"

    # Basic query as postgres superuser (peer auth via sudo)
    ${config.host.name}.succeed("sudo -u postgres psql -c 'SELECT 1'")

    # Check that ensureDatabases created the expected databases
    dbs = ${config.host.name}.succeed("sudo -u postgres psql -tAc 'SELECT datname FROM pg_database'")
    assert "n8n" in dbs, "missing n8n database"
    assert "nextcloud" in dbs, "missing nextcloud database"
  '';
};
```

### Redis Local (nixio)
```nix
server.tests.units.redis-ping = {
  testScript = { config, ... }: ''
    # PING
    out = ${config.host.name}.succeed("redis-cli -h localhost -p ${toString (config.services.redis.servers."").port} PING")
    assert "PONG" in out, f"redis PING failed: {out}"

    # SET/GET roundtrip
    ${config.host.name}.succeed("redis-cli -h localhost SET test_key test_value")
    out = ${config.host.name}.succeed("redis-cli -h localhost GET test_key")
    assert "test_value" in out, f"redis SET/GET failed: {out}"
  '';
};
```

### Postgres Exporter (nixio, Phase 2)
```nix
server.tests.units.postgres-exporter = {
  testScript = { config, ... }: ''
    port = "${toString config.services.prometheus.exporters.postgres.port}"
    ${config.host.name}.wait_for_open_port(port)
    out = ${config.host.name}.succeed("curl -sf http://localhost:${port}/metrics")
    assert "pg_up" in out, "postgres exporter metrics missing pg_up"
  '';
};
```

### Redis Exporter (nixio, Phase 2)
```nix
server.tests.units.redis-exporter = {
  testScript = { config, ... }: ''
    port = "${toString config.services.prometheus.exporters.redis.port}"
    ${config.host.name}.wait_for_open_port(port)
    out = ${config.host.name}.succeed("curl -sf http://localhost:${port}/metrics")
    assert "redis_up" in out, "redis exporter metrics missing redis_up"
  '';
};
```

### Pgadmin (nixio, Phase 2)
```nix
server.tests.units.pgadmin = {
  testScript = { config, ... }: ''
    ${config.host.name}.wait_for_open_port(${toString config.services.pgadmin.port})
    out = ${config.host.name}.succeed("curl -sf http://localhost:${toString config.services.pgadmin.port}/login")
    assert "pgAdmin" in out, "pgadmin login page not served"
  '';
};
```

## Scenario Tests

### `postgres-remote-connect` (Phase 1)
- **Nodes**: nixio (postgres primary) + any non-IO host (nixdev)
- **Assert**: Non-IO host connects to nixio:5432, authenticates, runs SELECT 1
- **Key wiring**: `config.server.database.host` must resolve in VM network

Implementation:
```nix
{
  nodes = {
    nixio = { ... };
    nixdev = { ... };
  };
  testScript = ''
    nixio.start()
    nixdev.start()
    nixio.wait_for_unit("postgresql.service")
    nixdev.wait_for_unit("multi-user.target")

    with subtest("remote postgres connect"):
      # Use postgres client from nixdev to connect to nixio
      nixdev.succeed(
          "psql -h nixio -U postgres -d postgres -c 'SELECT 1'"
      )
      nixdev.succeed(
          "psql -h nixio -U nextcloud -d nextcloud -c 'SELECT 1'"
      )
  '';
}
```

### `redis-remote-connect` (Phase 1)
- **Nodes**: nixio + non-IO host
- **Assert**: Remote Redis PING succeeds

### `database-backup-chain` (Phase 3)
- **Nodes**: nixio (postgres + minio) + nixcloud (nextcloud)
- **Assert**: pg_dump → minio bucket → s3fs mount

## Untestable

- Real postgres replication streaming (needs WAL archiving setup, not configured)
- CouchDB (currently disabled in config, `enable = false`)
- Real pg_dump to remote minio in multi-node (needs s3fs mount to work cross-host)
