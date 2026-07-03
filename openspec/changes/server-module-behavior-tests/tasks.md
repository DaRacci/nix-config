# Tasks: Server Module Behavior Tests

## 1. Foundation & Shared Infrastructure

- [x] 1.1 Create `tests/scenarios/network-policy/default.nix` with VM node definition for single-host iptables assertions (nixio node, `vm-test.nix` profile, subnet config inline).
- [x] 1.2 Create `tests/scenarios/runtime-infrastructure/default.nix` with two-node VM topology (nixio builder, nixdev client) and deterministic SSH key injection via VM profile.
- [x] 1.3 Create `tests/scenarios/proxy-extension-behavior/default.nix` with two-node VM topology (nixio proxy, nixcloud backend echo server) and self-signed TLS cert generation at build time.
- [x] 1.4 Create `tests/scenarios/monitoring-pipeline/default.nix` with two-node VM topology (nixmon collector, nixio target) and deterministic OTLP bearer token.
- [x] 1.5 Create `tests/scenarios/guardian-drain-lifecycle/default.nix` with two-node VM topology (nixio PG primary, nixdev guardian client) and deterministic `IO_GUARDIAN_PSK` via profile.
- [x] 1.6 Create `tests/scenarios/seaweedfs-storage-behavior/default.nix` with single-node VM config (nixio) running full SeaweedFS service graph + self-signed TLS certs + JWT tokens.

## 2. Phase 1 — Host Unit Tests

- [x] 2.1 Add `server.tests.units.postgres-init-merge` on nixio: assert `services.postgresql.initialScript` contains merged content from `server.database.postgres.databases.*.initScript`.
- [x] 2.2 Add `server.tests.units.redis-db-id-isolation` on nixio: assert each `server.database.redis.<name>` resolves to distinct logical DB ID via `database_id`.

## 3. Phase 1 — Network Policy Scenario (single-node, low risk)

- [x] 3.1 Implement `tests/scenarios/network-policy/test.nix`: configure two subnets with `openPortsForSubnet` (TCP 5432,8080; UDP 51820,53). Assert `iptables -S nixos-fw` contains rules for each port × subnet combination.
- [x] 3.2 Assert IPv4 source CIDR matches configured subnets in iptables rules.
- [x] 3.3 Assert `extraCommands` and `extraStopCommands` generated rules exist after boot.
- [x] 3.4 Assert only configured ports appear in nixos-fw chain — no unexpected TCP/UDP ports.
- [x] 3.5 Run `nix fmt .`, update `docs/src/development/vm_integration_tests.md` with network-policy scenario row.

## 4. Phase 1 — Runtime Infrastructure Scenario (two-node, low risk)

- [x] 4.1 Implement `tests/scenarios/runtime-infrastructure/test.nix`: assert `builder` user exists on nixio, authorized_keys contains nixdev's root public key.
- [x] 4.2 Assert SSH connectivity: from nixdev, `ssh builder@nixio echo hello` succeeds.
- [x] 4.3 Assert `/etc/nix/machines` on nixdev includes nixio with `ssh-ng` protocol.
- [x] 4.4 Assert SSH shell guard fires on root SSH into nixio — verify `SSH_NIX_SHELL` env var is set (or equivalent indicator).
- [x] 4.5 Assert `NIX_SKIP_SHELL=1` opt-out works — normal shell on SSH, no nix-shell entry.
- [x] 4.6 If feasible (based on SSH transport), assert `nix store ping --store ssh-ng://builder@nixio` succeeds.
- [x] 4.7 Run `nix fmt .`, update `docs/src/development/vm_integration_tests.md` with runtime-infrastructure scenario row.

## 5. Phase 1 — Verification

- [x] 5.1 Build and run `network-policy` scenario: `nix build .#checks.<system>.network-policy-vm-tests`.
- [x] 5.2 Build and run `runtime-infrastructure` scenario.
- [x] 5.3 Run `server.tests.units` on nixio host: verify postgres-init-merge and redis-db-id-isolation tests pass.
- [x] 5.4 Fix any module code adjustments needed for testability (iptables extraCommands wiring, builder user SSH key injection). Update affected module files and docs in parallel.

## 6. Phase 2 — Proxy Extension Behavior Scenario (two-node, medium risk)

- [x] 6.1 Implement localhost rewrite assertions: configure vhost with `reverse_proxy http://localhost:8080`, verify generated Caddy config resolves to `nixcloud:8080`. Assert via admin API or config file read.
- [x] 6.2 Implement API-key auth assertions: assert `/health` returns 200 without key (bypass), `/api/data` returns 401 without key, returns 200 with correct `Req-API-Key` header.
- [x] 6.3 Implement L4 TCP forwarding assertions: connect to L4 listen port on nixio, verify data roundtrip reaches nixcloud:9090 echo server.
- [x] 6.4 Implement extension priority assertions: verify Caddy extension output ordering matches `server.proxy.extensions` priority values.
- [x] 6.5 Run `nix fmt .`, update `docs/src/development/vm_integration_tests.md` with proxy-extension-behavior scenario row.

## 7. Phase 2 — Monitoring Pipeline Scenario (two-node, medium risk)

- [x] 7.1 Implement scrape target assertions: query Prometheus `/api/v1/targets` on nixmon, verify nixio:9100 (node), nixio:2019 (caddy), nixio:9187 (postgres) are active and `up`.
- [x] 7.2 Implement metrics reachability: query `up{job="node"}` via `/api/v1/query`, verify non-empty result with target state.
- [x] 7.3 Implement log shipping assertions: write deterministic log line on nixio via `logger`, query Loki on nixmon via `loki/api/v1/query_range`, assert content and host label match.
- [x] 7.4 Implement alert routing assertions: verify Prometheus alert rules are loaded via `/api/v1/rules`. If feasible, fire a test alert and confirm it reaches Alertmanager.
- [x] 7.5 Implement OTLP ingestion (feasibility gated): feasibility-gated — alloy OTLP endpoint not responding in QEMU test env; config generation verified via file inspection. Runtime ingestion deferred as documented.
- [x] 7.6 Run `nix fmt .`, update `docs/src/development/vm_integration_tests.md` with monitoring-pipeline scenario row.

## 8. Phase 2 — Verification

- [x] 8.1 Build and run `proxy-extension-behavior` scenario.
- [x] 8.2 Build and run `monitoring-pipeline` scenario.
- [x] 8.3 Fix any module code adjustments needed for testability (Caddy admin API access, alloy config introspection for tests). Update affected module files and docs in parallel.

## 9. Phase 3 — Guardian Drain Lifecycle Scenario (two-node, higher risk)

- [x] 9.1 Implement drain assertions: stop postgres on nixio, verify `io-database-coordinator` ExecStop runs `--action drain`, verify drain trigger reaches nixdev via io-guardian service log.
- [x] 9.2 Implement undrain assertions: start postgres on nixio, verify `io-database-coordinator` ExecStart runs `--action undrain`, verify nixdev receives undrain and dependent services restart.
- [x] 9.3 Implement systemd gating assertions: verify `io-databases.target` on nixdev transitions to active after postgres is healthy and undrained. Verify dependent services start only after target is reached.
- [x] 9.4 Implement application-level PG ping assertion: verify `wait-for-io-databases` uses `psql -c "SELECT 1"` (or equivalent), not mere TCP port check, by asserting the check fails if postgres accepts TCP but rejects queries (e.g., during recovery mode).
- [x] 9.5 Run `nix fmt .`, update `docs/src/development/vm_integration_tests.md` with guardian-drain-lifecycle scenario row.
- [x] 9.6 Update `docs/modules/nixos/server/database/guardian.md` if test revealed missing documentation (e.g., PSK configurability, drain/undrain observable signals).

## 10. Phase 3 — Verification

- [x] 10.1 Build and run `guardian-drain-lifecycle` scenario.
- [x] 10.2 Fix any guardian module code adjustments for test compatibility (e.g., making PSK configurable for deterministic test injection). Update docs in parallel.

## 11. Phase 4 — SeaweedFS Storage Behavior Scenario (single-node, highest risk)

- [x] 11.1 Research FUSE mount feasibility in QEMU VM: write a spike script checking `/dev/fuse` availability and kernel `CONFIG_FUSE_FS`. Document findings in `docs/src/development/vm_integration_tests.md`.
- [x] 11.2 Implement master leader election assertion: run `weed shell -master=localhost:9333 -command "cluster.status"`, verify leader info and volume server registration.
- [x] 11.3 Implement bucket creation and cross-surface visibility: create bucket via S3 API, assert visibility via S3 listing, filer HTTP API, and volume assignment.
- [x] 11.4 Implement object upload/retrieval roundtrip: upload file via S3 PUT, retrieve via filer HTTP GET, verify content match. Assert filer metadata reports correct size and ETag.
- [x] 11.5 Implement S3 bucket listing assertion: `aws s3api list-buckets` returns created bucket.
- [x] 11.6 Assert Admin UI responds on port 23646.
- [x] 11.7 If FUSE feasible (from 11.1), implement mount I/O assertions: write deterministic file to FUSE mount, read back, verify checksum match. Assert filer API reports file existence.
- [x] 11.8 If FUSE feasible, implement volume server restart resilience: restart seaweedfs-volume, verify FUSE mount remains accessible and pre-existing file is readable.
- [x] 11.9 Implement master restart resilience: restart seaweedfs-master, verify leader re-election and pre-existing bucket/object accessibility.
- [x] 11.10 Run `nix fmt .`, update `docs/src/development/vm_integration_tests.md` with seaweedfs-storage-behavior scenario row.
- [x] 11.11 Update `docs/modules/nixos/server/storage/seaweedfs.md` with FUSE feasibility findings and test configuration guidance.

## 12. Phase 4 — Verification

- [x] 12.1 Build and run `seaweedfs-storage-behavior` scenario.
- [x] 12.2 Fix any SeaweedFS module code adjustments for test compatibility (service ordering, TLS cert paths, JWT seed determinism). Update docs in parallel.

## 13. Final Full-Suite Verification

- [x] 13.1 Run all six scenarios in a single CI-compatible invocation: verify no regression or cross-scenario interference.
- [x] 13.2 Run `nix fmt .` across entire repository.
- [x] 13.3 Verify all `docs/` entries are consistent with final module state — no stale references to removed options, no missing scenario table entries.
- [x] 13.4 Run `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` to confirm flake integrity.
