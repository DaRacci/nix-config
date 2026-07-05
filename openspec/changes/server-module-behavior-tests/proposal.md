## Why

The `comprehensive-server-tests` change validates service reachability — ports open, HTTP 200, PING response, unit active. These checks confirm services start but not that they work correctly.

Our custom modules under `modules/nixos/server/` contain real orchestration logic that shallow tests miss. Examples:

- **Guardian** (`database/guardian.nix`): Drains downstream database consumers during PG stop, undrains them on restart. A PG restart on nixio should propagate drain to dependent services on non-IO hosts. No test proves this.
- **SeaweedFS** (`storage/seaweedfs.nix`): Bucket creation through filer/S3 API, volume server assignment, master leader election, FUSE mount I/O roundtrip. Checking ports `:9333/:8080/:8888` is not the same as proving the cluster stores and retrieves data.
- **Proxy extensions** (`proxy/`): Localhost rewrite strips `X-Forwarded-For`, Kanidm API-key auth validates tokens via upstream IdP, L4 routing forwards raw TCP. None of this is exercised today.
- **Network module** (`network.nix`): Subnet-scoped firewall rules are generated from host metadata. No test asserts that only declared ports are open per subnet or that rule generation is correct.
- **Monitoring** (`monitoring/`): Scrape targets are generated from host service config, alert routing depends on receiver topology, OTLP ingestion processes real telemetry. None of this is validated.
- **Runtime infrastructure** (`distributed-builds.nix`, `ssh-shell/`): SSH builder user setup, nix ping-store across hosts, custom SSH shell restrictions — all custom logic, all untested.

Each of these bugs reaches production undetected because baseline VM tests and shallow port checks pass regardless of behavioral correctness.

## What Changes

Introduce 6 new VM integration scenarios that exercise custom module behavior end-to-end. Each scenario uses production-like multi-node topology and asserts observable outcomes — not just process state.

| Scenario | Custom Modules Exercised | Behavioral Assertion |
|---|---|---|
| Guardian drain lifecycle | `database/guardian.nix`, `database/postgres.nix` | PG stop/start on IO primary propagates drain/undrain to remote dependent service host |
| SeaweedFS storage operations | `storage/seaweedfs.nix` | Bucket creation visible via S3 API, filer list, and volume server; FUSE mount write/read roundtrip |
| Proxy routing extensions | `proxy/` (rewrite, auth, L4) | Localhost rewrite transforms headers correctly; API-key auth rejects unauthenticated requests; L4 TCP forwarding reaches backend |
| Monitoring pipeline | `monitoring/` (scrape, log-ship, alert, OTLP) | Prometheus target list includes hosts declared in config; Loki receives logs from remote alloy; OTLP metrics ingested and queryable |
| Network policy generation | `network.nix` | Subnet-scoped firewall rules on each host match declared `allowedTCPPorts`; cross-host rule sync produces identical policy on paired hosts |
| Runtime infrastructure | `distributed-builds.nix`, `ssh-shell/` | SSH builder user connects to remote nix store and runs builds; custom SSH shell restricts commands to authorized set |

Each scenario builds on the infrastructure delivered by `testing-framework-predeploy` and complements — does not replace — the per-host unit tests and existing scenarios from `comprehensive-server-tests`.

## Capabilities

### New Capabilities

- **guardian-drain-lifecycle-vm-tests** — Multi-node scenario that stops and restarts PostgreSQL on the IO host while observing drain/undrain signals on a dependent non-IO host. Asserts the dependent service's connection pool is drained before PG stop and re-established after PG ready.
- **seaweedfs-storage-behavior-vm-tests** — Multi-node scenario (master + volume + filer + FUSE client). Creates a bucket via S3 API, verifies it appears in filer directory listing and on the volume server. Mounts volume via FUSE, writes a file, reads it back, verifies checksum match.
- **proxy-extension-behavior-vm-tests** — Three-node scenario (proxy host + backend host + auth provider host). Asserts localhost rewrite headers are correct on proxied request to backend. Asserts Kanidm API-key auth request succeeds with valid key and returns 401 with invalid key. Asserts L4 TCP forwarding reaches backend on correct port.
- **monitoring-pipeline-vm-tests** — Three-node scenario (monitoring host + target host + OTLP client host). Asserts Prometheus targets include the target host's declared exporters. Asserts Loki receives log lines shipped from target host's alloy. Asserts OTLP metrics submitted from client host appear in Prometheus query results.
- **network-policy-vm-tests** — Two-node scenario with paired hosts sharing a declared subnet. Asserts each host's `iptables`/`nftables` rules allow only declared `allowedTCPPorts`. Asserts paired hosts produce identical rule sets. Asserts host outside the subnet cannot reach internal ports.
- **runtime-infrastructure-vm-tests** — Two-node scenario (builder host + build worker host). Asserts SSH builder user exists on worker with authorized key from nixio config. Asserts `nix store ping` succeeds from builder to remote store. Asserts custom SSH shell (if any) rejects unauthorized commands.

### Modified Capabilities

- None. This change adds new test scenarios only. No existing spec capabilities are modified, nor are existing modules refactored.

## Non-goals

- Replacing or duplicating the per-host unit tests or existing scenario tests from `comprehensive-server-tests`
- Adding port-level or service-level assertions that overlap with `comprehensive-server-tests` (e.g., "postgres port 5432 is open" is already covered)
- Testing upstream nixpkgs service behavior (postgres replication, prometheus scraping, sshd hardening — these belong to nixpkgs)
- Production end-to-end testing or synthetic transaction monitoring against live hosts
- Performance, load, or stress testing
- UI or dashboard-level testing (Grafana, Dashy, pgAdmin interface)
- Testing services permanently out of scope per `testing-framework-predeploy` (tailscale, ollama with GPU, cloudflared tunnel, ACME cert renewal)
- Refactoring any existing module code — tests are observational only
- **Hand-rolling module equivalent config** in scenario nodes. Every VM scenario
  must validate repository-owned module logic, not inline re-implementations of
  that same logic. Duplicated config will drift from the deployed module and
  produce false test signals.

## Impact

- **Affected NixOS configurations:** All 7 server hosts serve as nodes across the 6 scenarios. Specifically: `nixio` participates in Guardian, SeaweedFS, proxy, monitoring, network, and runtime scenarios; `nixcloud`, `nixdev`, `nixai`, `nixarr`, `nixserv`, `nixmon` each participate as dependent/remote/target hosts in relevant scenarios.
- **Affected home-manager configurations:** None. All scenarios are NixOS-only multi-node VM tests.
- **Build cost:** Each scenario adds 2–3 VM nodes to the CI test suite. Estimated total additional CI time: 15–25 minutes per full run. Scenarios are independent and can execute in parallel.
- **External dependencies:** Same as `testing-framework-predeploy` — QEMU/KVM, Woodpecker runner with adequate disk (40GB+ for parallel multi-node scenarios). No new external services.
- **Maintenance burden:** Each scenario is self-contained in `tests/scenarios/<name>/`. Module changes that alter the tested behavior surface must update the corresponding scenario's `testScript` assertions. This is by design — breaking changes in custom modules now produce test failures instead of silent divergence.
