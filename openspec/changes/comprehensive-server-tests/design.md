## Context

7 server hosts, each wired with infrastructure modules from `modules/nixos/server/`. The fleet architecture:

```
                 Internet
                    |
              [cloudflared tunnel]
                    |
               nixio (IO Primary)
              /    |    \       \
          postgres redis caddy  minio
           /  |   \     |        |
      nixcloud  nixdev  nixmon  (all hosts)
      nixarr    nixserv
      nixai
```

- **nixio** — IO primary. Runs postgres, redis, caddy reverse proxy, minio storage, adguard, dashy dashboard, pgadmin, seaweedfs
- **nixmon** — Monitoring primary. Runs prometheus, loki, grafana, alertmanager, uptime-kuma
- **nixcloud** — Cloud services. Runs kanidm (auth), nextcloud, immich, homebox, navidrome, searxng, home-assistant
- **nixdev** — Dev tools. Runs woodpecker (server+agent), n8n, coder, attic cache, docker registry, 10 GitHub runners
- **nixai** — AI. Runs open-webui, hermes AI agent, wyoming STT/TTS, ollama (disabled in VM), mcpo (disabled in VM)
- **nixarr** — Media. Runs nixarr suite (jellyfin, seerr, *arr stack) behind VPN
- **nixserv** — Lightweight. Runs atticd (binary cache)

Non-IO hosts connect to nixio for postgres and redis via `server.database.host`. The IO guardian protocol coordinates database availability.

## Test Architecture

```
server.tests.units                          tests/scenarios/
    │                                            │
    │ per-host, cheap,                          │ multi-node, expensive,
    │ no cross-host deps                        │ cross-service deps
    │                                            │
    ▼                                            ▼
tests/builder.nix (dual-mode builder)
    │
    ├── each <host> wraps production config
    │   + vm-test.nix (override profile)
    │   + unit testScript collected from
    │     host's server.tests.units
    │
    └── each <scenario> wraps custom nodes
        + vm-test.nix (on every node)
        + scenario testScript
```

### Authoring Pattern

**Unit test** (in host config, e.g. `hosts/server/nixio/database.nix`):
```nix
server.tests.units.postgres-connect = {
  testScript = ''
    nixio.succeed(
        "sudo -u postgres psql -c 'SELECT 1'"
    )
  '';
};
```

**Scenario** (in `tests/scenarios/<name>/test.nix`):
```nix
{
  nodes = {
    source = { ... };
    target = { ... };
  };
  testScript = ''
    # cross-node assertions here
  '';
}
```

## Coverage Matrix

### Host: nixio (IO Primary)

| Service | Module/File | Unit Test | Type | Phase |
|---|---|---|---|---|
| postgresql | `hosts/server/nixio/database.nix` | Connect, query, pg_isready | port-check + cmd | 1 |
| redis | `database/redis.nix` | PING, SET/GET | port-check + cmd | 1 |
| caddy | `hosts/server/nixio/proxy.nix` | HTTP 200 on / | http-get | 1 |
| minio | `hosts/server/nixio/storage.nix` | HTTP 200 on /minio/health/live | http-get | 1 |
| adguard | `hosts/server/nixio/adguard.nix` | HTTP 200 on / | http-get | 1 |
| dashy | `hosts/server/nixio/dashboard.nix` | HTTP 200 on / | http-get | 1 |
| pgadmin | `database/default.nix` | HTTP 200 on /login | http-get | 2 |
| seaweedfs | `storage/seaweedfs.nix` | Master/Volume/Filer all responding | http-get (3 ports) | 2 |
| postgres-exporter | `monitoring/exporters/postgres.nix` | Metrics endpoint | http-get | 2 |
| redis-exporter | `monitoring/exporters/redis.nix` | Metrics endpoint | http-get | 2 |
| postgresqlBackup | `database.nix` | Backup dir exists, recent dump | file-check | 2 |
| kernel-sysctl | `default.nix` | ip_forward = 1 | cmd | 1 (in baseline) |
| upgrade-status | `proxy.nix` | systemd unit exists | cmd | 3 |
| hacompanion | `proxy.nix` | systemd unit exists | cmd | 3 |

### Host: nixmon (Monitoring Primary)

| Service | Unit Test | Type | Phase |
|---|---|---|---|
| prometheus | HTTP 200 on /api/v1/status/buildinfo | http-get | 1 |
| loki | HTTP 200 on /ready | http-get | 1 |
| grafana | HTTP 200 on /api/health | http-get | 1 |
| alertmanager | HTTP 200 on /-/ready | http-get | 1 |
| uptime-kuma | HTTP 200 on / | http-get | 1 |
| node-exporter | Metrics endpoint on :9100/metrics | http-get | 1 |
| alloy | Loki journal shipping running | cmd | 2 |

### Host: nixcloud

| Service | Unit Test | Type | Phase |
|---|---|---|---|
| kanidm | HTTP on :8443 | port-check | 1 |
| nextcloud | HTTP 200 on /status.php | http-get | 1 |
| immich | HTTP on port | port-check | 1 |
| home-assistant | HTTP 200 on / | http-get | 1 |
| navidrome | HTTP on port | port-check | 2 |
| searxng | HTTP 200 on / | http-get | 2 |
| homebox | HTTP on port | port-check | 2 |
| elasticsearch | HTTP 200 on / | http-get | 2 |
| clamav | Socket exists | file-check | 3 |
| imaginary | HTTP on port | port-check | 3 |
| music-assistant | `home-assistant/music.nix` | HTTP GET :8095 | http-get | 2 |
| mosquitto | `home-assistant/connectivity.nix` | pub/sub roundtrip | cmd | 2 |
| esphome | `home-assistant/connectivity.nix` | port check | port-check | 3 |
| zigbee2mqtt | `home-assistant/connectivity.nix` | port check | port-check | 3 |
| matter-server | `home-assistant/connectivity.nix` | service active | cmd | 3 |
| avahi | `home-assistant/default.nix` | avahi-daemon --check | cmd | 3 |
| notify-push | `nextcloud.nix` | service active | cmd | 3 |
| redis (local immich) | PING | cmd | 3 |

### Host: nixdev

| Service | Unit Test | Type | Phase |
|---|---|---|---|
| woodpecker-server | HTTP 200 on / | http-get | 1 |
| woodpecker-agent | gRPC port open | port-check | 1 |
| n8n | HTTP 200 on /healthz | http-get | 1 |
| coder | HTTP 200 on /api/v2/buildinfo | http-get | 1 |
| atticd | HTTP 200 on / | http-get | 1 |
| docker-registry | HTTP 200 on /v2/ | http-get | 1 |
| docker daemon | Socket exists | file-check | 1 |
| GitHub runners | Service active | cmd | 3 (no token = won't start) |

### Host: nixai

| Service | Unit Test | Type | Phase |
|---|---|---|---|
| open-webui | HTTP on port | port-check | 1 |
| ai-agent (hermes) | API server port open | port-check | 1 |
| ai-agent dashboard | HTTP on port | port-check | 1 |
| wyoming-piper | TCP socket on :10200 | port-check | 2 |
| wyoming-whisper | TCP socket on :10300 | port-check | 2 |
| ollama | DISABLED in VM | — | — |
| mcpo | DISABLED in VM | — | — |

### Host: nixarr

| Service | Unit Test | Type | Phase |
|---|---|---|---|
| jellyfin | HTTP on port | port-check | 1 |
| seerr | HTTP on port | port-check | 1 |
| nixarr (*arr stack) | HTTP on *arr ports | port-check | 2 |
| wg (VPN) | Interface up | cmd | 2 |
| samba | `arr/music.nix` | smbclient list shares | cmd | 2 |
| flaresolverr | `arr/default.nix` | service present | cmd | 3 |
| transmission | `arr/downloader.nix` | port check | port-check | 3 |
| sabnzbd | `arr/downloader.nix` | port check | port-check | 3 |

### Host: nixserv

| Service | Unit Test | Type | Phase |
|---|---|---|---|
| atticd | HTTP 200 on / | http-get | 1 |
| atticd-config | `default.nix` | DB URL points to nixio | cmd | 3 |

## Cross-Service Scenarios

### 1. Scenario: `postgres-remote-connect`
- **Nodes**: nixio (postgres primary) + any non-IO host (e.g., nixdev)
- **Asserts**: non-IO host reaches nixio:5432, authenticates, runs SELECT 1
- **Cost**: 2 VMs, ~8min build
- **Phase**: 1

### 2. Scenario: `redis-remote-connect`
- **Nodes**: nixio (redis primary) + any non-IO host
- **Asserts**: non-IO host reaches nixio:6379, PONG response
- **Cost**: 2 VMs, ~8min
- **Phase**: 1

### 3. Scenario: `monitoring-scrape`
- **Nodes**: nixmon (collector) + nixio (exporter target)
- **Asserts**: nixmon prometheus scrapes node/caddy/postgres metrics from nixio; loki receives logs
- **Cost**: 2 VMs, ~10min
- **Phase**: 2

### 4. Scenario: `proxy-routing`
- **Nodes**: nixio (caddy reverse proxy) + nixcloud (nextcloud backend)
- **Asserts**: HTTP request through caddy on nixio reaches nextcloud on nixcloud
- **Cost**: 2 VMs, ~8min
- **Phase**: 2

### 5. Scenario: `database-backup-chain`
- **Nodes**: nixio (postgres+minio) + nixcloud (nextcloud reliant on DB)
- **Asserts**: pg_dumpall succeeds, dump lands in minio bucket, s3fs mountable
- **Cost**: 2 VMs, ~10min
- **Phase**: 3

### 6. Scenario: `io-guardian-coordination`
- **Nodes**: nixio (coordinator) + one non-IO host
- **Asserts**: io-database-coordinator service active on nixio, port 9876 reachable, non-IO wait script completes
- **Cost**: 2 VMs, ~8min
- **Phase**: 3

### 7. Scenario: `pgvector-extension`
- **Nodes**: nixio (postgres) + nixcloud
- **Asserts**: pgvector extension installed on cluster database
- **Cost**: 2 VMs, ~8min
- **Phase**: 3

## Infrastructure Tests

### `storage-mount`
- **Host**: nixio (minio host) or any host with `swfsMount`
- **Asserts**: FUSE mountpoint exists, directory writable, health check timer active
- **Phase**: 2

### `distributed-builds`
- **Host**: all hosts with `server.distributedBuilds` enabled
- **Asserts**: builder user exists, SSH authorized_keys present, `nix ping-store` works
- **Phase**: 2

## Security Tests

### `firewall-port-audit`
- **Host**: every host
- **Asserts**: Ports returned by `ss -tlnp` match allowedTCPPorts in config. No unexpected listeners.
- **Phase**: 2

### `ssh-hardening`
- **Host**: every host
- **Asserts**: `PasswordAuthentication no`, root login key-only, banner set
- **Phase**: 3

## VM Profile Limitations

Some services won't fully start in VMs despite being enabled in config. Tests must account for this:

| Service | Reason | Test Strategy |
|---------|--------|---------------|
| nextcloud, immich, loki | `swfsMount` FUSE mounts fail without S3/seaweedfs backend | Verify service definitions, not HTTP health |
| *arr stack, transmission, sabnzbd | Require WireGuard VPN tunnel | Verify service definitions, accept inactive |
| kanidm | Requires ACME cert from Cloudflare DNS challenge | Verify service definition, not HTTP |
| n8n | Connects to remote postgres/redis on nixio | Verify service definition, healthz may fail |
| adguard | Requires ACME cert | Verify service definition |
| GitHub runners | Require real runner registration token | Verify service unit exists |

## Services Permanently Out of Scope

| Service | Reason |
|---|---|
| tailscale | Needs real tailnet auth — disabled by vm-test profile |
| mcpo | Needs live OAuth tokens — disabled by vm-test profile |
| ollama | Needs GPU — disabled by vm-test profile |
| cloudflared tunnel ingress | Needs real tunnel credentials |
| ACME cert renewal | Needs Cloudflare DNS API — no challenge in VM |
| GitHub Actions runners | Needs real runner registration token |
| Home Assistant HW integrations | Needs Zigbee/Thread/BT radios |

These services' configurations are still evaluated (module imports, option types, sops wiring) but runtime behavior cannot be validated in VM.
