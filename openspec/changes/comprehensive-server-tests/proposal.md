## Why

The testing framework (testing-framework-predeploy) delivers VM boot + baseline per host. No service-level assertions exist beyond "system boots, no failed units." That's a wide gap — a postgres misconfig, a Caddy directive gone wrong, or a firewall hole surfacing post-merge all pass baseline and get deployed.

7 hosts run ~40 services across postgres, redis, caddy, minio, seaweedfs, loki, prometheus, grafana, kanidm, nextcloud, immich, woodpecker, n8n, coder, attic, nixarr suite, home-assistant, and more. Each has config wiring that can break independently. The proxy layer alone routes ~25 virtual hosts across 5 non-IO hosts.

Cross-service interactions compound the risk:
- Non-IO hosts connect to nixio for postgres/redis — disconnect scenario untested
- Monitoring collector on nixmon scrapes all hosts — target config drift untested
- SeaweedFS migration path (MinIO → SeaweedFS) has no pre-deploy validation
- Firewall rules per service accumulate silently — no regression detection

## What Changes

~48 new `server.tests.units` entries across all 7 hosts + 7 new multi-node scenarios + 2 infrastructure test suites + 1 security test suite.

### Per-Host Unit Tests (Phase 1)

Each active service on every host gets a `server.tests.units.<service>` entry asserting:
- Service socket/port listening
- Basic protocol-level response (HTTP 200, PG query, Redis PING, etc.)
- Systemd unit active (not just socket, but actual service)

### Cross-Service Scenarios (Phase 1-2)

| Scenario | Nodes | What it tests |
|---|---|---|
| postgres-replication | non-io → nixio | Remote DB connect, auth, query |
| redis-connect | non-io → nixio | Remote Redis PING/SET/GET |
| monitoring-scrape | nixmon → all | Prometheus targets reachable, metrics served |
| proxy-routing | nixio → all | Caddy reverse-proxy routes resolve |
| database-backup-chain | non-io + nixio + nixmon | PG dump, s3fs mount, loki reads backup dir |
| io-guardian | nixio → non-IO | IO coordinator protocol, port 9876 reachable |
| pgvector-extension | nixcloud → nixio | pgvector available on cluster DB |

### Infrastructure Tests (Phase 2)

| Test | What it validates |
|---|---|
| storage-mount | s3fs/seaweedfs FUSE mount services start, directories writable |
| distributed-builds | SSH builder user exists, nix ping-store succeeds |

### Security Tests (Phase 2-3)

| Test | What it validates |
|---|---|
| firewall-port-audit | Only declared ports open; no unexpected listeners |
| ssh-hardening | Root pw auth disabled, key-only, banner present |

### Services NOT Testable in VMs

| Service | Reason | Mitigation |
|---|---|---|
| tailscale | Needs auth key / OAuth client | Manual prod validation |
| mcpo | Needs GitHub/AniList/Hassio tokens | Manual prod validation |
| ollama | Needs GPU passthrough | Manual prod validation |
| cloudflared tunnel | Needs real tunnel creds | Config syntax validated by caddy eval |
| ACME cert renewal | Needs real DNS challenge | N/A — certs are test dummies |
| GitHub runners | Needs real runner token | N/A — auth token not present |
| Home Assistant HW integration | Needs real Zigbee/thread/BT hardware | Config eval only |
| Kanidm OAuth2 flow | Needs full IdP ↔ SP roundtrip | Service reachable, port-check only |

## Non-goals

- Replacing existing `checks.cluster` or the baseline assertions
- Running real integration tests against production
- Testing non-NixOS services or external dependencies (Cloudflare, GitHub, AniList)
- Post-deployment monitoring or synthetic transaction testing
- Performance/load testing
- TMate or end-to-end UI testing (Dashy, Grafana, pgAdmin)

## Impact

- Affected files: All 7 host configs (`hosts/server/*/*.nix`) get `server.tests.units` entries; `tests/scenarios/` gets 5 new dirs; CI eval time per PR increases 2-3x (more targets to build)
- Affected systems: All 7 server hosts — each gets service-level assertions gating deployment. CI runners need longer timeouts (Phase 1: ~15min total vs current ~8min)
- Build cost: ~40 unit tests add ~0.5-1s each to eval. Scenario tests add 1-2 nodes each. Total CI build time ~25-35min for full suite
- External dependencies: QEMU/KVM, Woodpecker runner with adequate disk (30GB+) for parallel VM builds
