## Phase 1: Critical Service Tests (~25 unit tests + 2 scenarios)

### 1.1 nixio — IO primary services
- [ ] 1.1.1 Add `server.tests.units.postgres-connect` to `hosts/server/nixio/database.nix` — `pg_isready`, SELECT 1 as postgres user
- [ ] 1.1.2 Add `server.tests.units.redis-ping` to `hosts/server/nixio/database.nix` — `redis-cli PING`, SET/GET roundtrip
- [ ] 1.1.3 Add `server.tests.units.caddy` to `hosts/server/nixio/proxy.nix` — HTTP GET localhost returns 200
- [ ] 1.1.4 Add `server.tests.units.minio` to `hosts/server/nixio/storage.nix` — HTTP GET /minio/health/live returns 200
- [ ] 1.1.5 Add `server.tests.units.adguard` to `hosts/server/nixio/adguard.nix` — HTTP GET localhost returns 200
- [ ] 1.1.6 Add `server.tests.units.dashy` to `hosts/server/nixio/dashboard.nix` — HTTP GET localhost returns 200
- [ ] 1.1.7 Add `server.tests.units.baseline-io` to `hosts/server/nixio/default.nix` — journald limits check, caddy config loaded

### 1.2 nixmon — Monitoring primary services
- [ ] 1.2.1 Add `server.tests.units.prometheus` to `hosts/server/nixmon/default.nix` — HTTP GET /api/v1/status/buildinfo
- [ ] 1.2.2 Add `server.tests.units.loki` to `hosts/server/nixmon/default.nix` — HTTP GET /ready
- [ ] 1.2.3 Add `server.tests.units.grafana` to `hosts/server/nixmon/default.nix` — HTTP GET /api/health
- [ ] 1.2.4 Add `server.tests.units.alertmanager` to `hosts/server/nixmon/default.nix` — HTTP GET /-/ready
- [ ] 1.2.5 Add `server.tests.units.uptime-kuma` to `hosts/server/nixmon/default.nix` — HTTP GET localhost:3001
- [ ] 1.2.6 Add `server.tests.units.node-exporter` to `hosts/server/nixmon/default.nix` — HTTP GET :9100/metrics

### 1.3 nixcloud — Cloud services
- [ ] 1.3.1 Add `server.tests.units.kanidm` to `hosts/server/nixcloud/identity.nix` — TCP socket :8443 reachable
- [ ] 1.3.2 Add `server.tests.units.nextcloud` to `hosts/server/nixcloud/nextcloud.nix` — HTTP GET /status.php returns 200
- [ ] 1.3.3 Add `server.tests.units.immich` to `hosts/server/nixcloud/immich.nix` — HTTP GET localhost returns 200
- [ ] 1.3.4 Add `server.tests.units.home-assistant` to `hosts/server/nixcloud/home-assistant/default.nix` — HTTP GET localhost returns 200

### 1.4 nixdev — Dev services
- [ ] 1.4.1 Add `server.tests.units.woodpecker-server` to `hosts/server/nixdev/woodpecker.nix` — HTTP GET localhost:8000
- [ ] 1.4.2 Add `server.tests.units.woodpecker-agent` to `hosts/server/nixdev/woodpecker.nix` — port :9000 reachable
- [ ] 1.4.3 Add `server.tests.units.n8n` to `hosts/server/nixdev/automation.nix` — HTTP GET /healthz returns 200
- [ ] 1.4.4 Add `server.tests.units.coder` to `hosts/server/nixdev/coder.nix` — HTTP GET /api/v2/buildinfo
- [ ] 1.4.5 Add `server.tests.units.atticd` to `hosts/server/nixserv/default.nix` — HTTP GET localhost:8080
- [ ] 1.4.6 Add `server.tests.units.docker-registry` to `hosts/server/nixdev/registry.nix` — HTTP GET /v2/ returns 200
- [ ] 1.4.7 Add `server.tests.units.docker` to `hosts/server/nixdev/default.nix` — docker info succeeds, socket exists

### 1.5 nixai — AI services
- [ ] 1.5.1 Add `server.tests.units.open-webui` to `hosts/server/nixai/web.nix` — HTTP GET localhost returns 200
- [ ] 1.5.2 Add `server.tests.units.ai-agent-api` to `hosts/server/nixai/ai-agent.nix` — API server port reachable
- [ ] 1.5.3 Add `server.tests.units.ai-agent-dashboard` to `hosts/server/nixai/ai-agent.nix` — Dashboard port reachable

### 1.6 nixarr — Media services
- [ ] 1.6.1 Add `server.tests.units.jellyfin` to `hosts/server/nixarr/default.nix` — HTTP GET localhost port
- [ ] 1.6.2 Add `server.tests.units.seerr` to `hosts/server/nixarr/default.nix` — HTTP GET localhost port

### 1.7 Cross-host scenarios
- [ ] 1.7.1 Create `tests/scenarios/postgres-remote-connect/test.nix` — nixio + non-IO host, remote PG connect
- [ ] 1.7.2 Create `tests/scenarios/redis-remote-connect/test.nix` — nixio + non-IO host, remote Redis PING

### 1.8 Verify
- [ ] 1.8.1 Build every Phase 1 unit test target: `nix build .#nixosTestConfigurations.<host>` for all 7 hosts
- [ ] 1.8.2 Build both Phase 1 scenario targets
- [ ] 1.8.3 Verify all pass in local QEMU

## Phase 2: Secondary Services & Infrastructure (~15 unit tests + 2 scenarios + 2 suites)

### 2.1 nixio — Secondary services
- [ ] 2.1.1 Add `server.tests.units.pgadmin` — HTTP GET /login
- [ ] 2.1.2 Add `server.tests.units.seaweedfs-master` — HTTP GET :9333
- [ ] 2.1.3 Add `server.tests.units.seaweedfs-volume` — HTTP GET :8080
- [ ] 2.1.4 Add `server.tests.units.seaweedfs-filer` — HTTP GET :8888
- [ ] 2.1.5 Add `server.tests.units.postgres-exporter` — HTTP GET :9187/metrics
- [ ] 2.1.6 Add `server.tests.units.redis-exporter` — HTTP GET :9121/metrics
- [ ] 2.1.7 Add `server.tests.units.postgresql-backup` — backup dir exists, recent dump
- [ ] 2.1.8 Add `server.tests.units.mosquitto` to nixcloud — port 1883 pub/sub roundtrip
- [ ] 2.1.9 Add `server.tests.units.samba` to nixarr — smbclient list shares
- [ ] 2.2.5 Add `server.tests.units.music-assistant` to nixcloud — HTTP GET port 8095
- [ ] 2.2.6 Add `server.tests.units.esphome` to nixcloud — port check

### 2.2 nixcloud — Secondary services
- [ ] 2.2.1 Add `server.tests.units.navidrome` — port check
- [ ] 2.2.2 Add `server.tests.units.searxng` — HTTP GET /
- [ ] 2.2.3 Add `server.tests.units.homebox` — port check
- [ ] 2.2.4 Add `server.tests.units.elasticsearch` — HTTP GET /

### 2.3 nixarr — VPN/media stack
- [ ] 2.3.1 Add `server.tests.units.wireguard` — `wg show` returns interface
- [ ] 2.3.2 Add *arr suite port checks (sonarr, radarr, etc.)

### 2.4 nixai — Voice services
- [ ] 2.4.1 Add `server.tests.units.wyoming-piper` — TCP socket :10200
- [ ] 2.4.2 Add `server.tests.units.wyoming-whisper` — TCP socket :10300

### 2.5 Infrastructure test suites
- [ ] 2.5.1 Create `tests/scenarios/storage-mount/test.nix` — FUSE mount point + writability
- [ ] 2.5.2 Create `tests/scenarios/distributed-builds/test.nix` — builder user + SSH keys + ping-store

### 2.6 Cross-host scenarios
- [ ] 2.6.1 Create `tests/scenarios/monitoring-scrape/test.nix` — nixmon + nixio, prometheus scrape + loki push
- [ ] 2.6.2 Create `tests/scenarios/proxy-routing/test.nix` — nixio caddy → nixcloud backend

### 2.7 Security suite — firewall-port-audit
- [ ] 2.7.1 Create `tests/scenarios/firewall-port-audit/test.nix` — compare ss output vs config for every host

### 2.8 nixmon — Alloy log shipping
- [ ] 2.8.1 Add `server.tests.units.alloy` — alloy service active + logs flowing

### 2.9 Verify
- [ ] 2.9.1 Build all Phase 2 targets
- [ ] 2.9.2 Run full Phase 1 + Phase 2 suite in CI

## Phase 3: Edge Cases & Deep Validation (~8 unit tests + 1 scenario)

### 3.1 nixcloud — Deep service checks
- [ ] 3.1.1 Add `server.tests.units.clamav` — socket exists
- [ ] 3.1.2 Add `server.tests.units.imaginary` — HTTP port check
- [ ] 3.1.3 Add `server.tests.units.immich-redis` — local Redis PING
- [ ] 3.1.4 Add `server.tests.units.zigbee2mqtt` to nixcloud — port check
- [ ] 3.1.5 Add `server.tests.units.matter-server` to nixcloud — service active
- [ ] 3.1.6 Add `server.tests.units.avahi` to nixcloud — avahi-daemon --check
- [ ] 3.1.7 Add `server.tests.units.notify-push` to nixcloud — service active

### 3.2 nixserv — Postgres socket connect
- [ ] 3.2.1 Add `server.tests.units.atticd-config` — verify DB URL points to nixio

### 3.3 nixdev — GitHub runner service check
- [ ] 3.3.1 Add `server.tests.units.github-runners` — service present (won't start without token, but unit exists)
- [ ] 3.3.2 Add `server.tests.units.flaresolverr` to nixarr — service present
- [ ] 3.3.3 Add `server.tests.units.transmission` to nixarr — port check
- [ ] 3.3.4 Add `server.tests.units.sabnzbd` to nixarr — port check

### 3.4 Cross-host scenario: full backup chain
- [ ] 3.4.1 Create `tests/scenarios/database-backup-chain/test.nix` — nixio postgres dump → minio → s3fs mount
- [ ] 3.4.2 Add `server.tests.units.kernel-forwarding` to nixio — sysctl ip_forward=1
- [ ] 3.4.3 Add `server.tests.units.upgrade-status` to nixio — systemd unit exists
- [ ] 3.4.4 Add `server.tests.units.hacompanion` to nixio — systemd unit exists

### 3.5 Security suite — ssh-hardening
- [ ] 3.5.1 Create `tests/scenarios/ssh-hardening/test.nix` — sshd config assertions
- [ ] 3.5.2 Create `tests/scenarios/io-guardian/test.nix` — nixio + non-IO host, guardian port 9876
- [ ] 3.5.3 Create `tests/scenarios/pgvector-extension/test.nix` — nixio + nixcloud, pgvector installed

### 3.6 Documentation
- [ ] 3.6.1 Update `docs/src/development/vm_integration_tests.md` with per-service test patterns
- [ ] 3.6.2 Add coverage matrix summary to docs
- [ ] 3.6.3 Document scenario authoring guidance for each interaction type

### 3.7 Verify
- [ ] 3.7.1 Build entire test suite end-to-end
- [ ] 3.7.2 Run full Phase 1-3 suite in CI
- [ ] 3.7.3 Verify docs render correctly in mdbook

## CI Impact

| Phase | Targets | Est. Build Time | Disk |
|---|---|---|---|
| Baseline (current) | 8 targets | ~8 min | ~15GB |
| Phase 1 | 25 unit + 2 scenario = 27 new | ~15 min | ~25GB |
| Phase 2 | 21 unit + 4 scenario + 2 infra + 1 security = 28 new | ~15 min | ~25GB |
| Phase 3 | 18 unit + 3 scenario + 1 security = 22 new | ~13 min | ~22GB |
| **Total** | **~85 targets** | **~51 min** | **~87GB** |

Mitigation: CI parallelism (Woodpecker multi-worker). Group targets by host affinity to reduce rebuild overhead.
