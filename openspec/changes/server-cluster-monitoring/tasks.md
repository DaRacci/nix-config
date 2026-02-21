## 1. Allocation and Module Foundation

- [x] 1.1 Add `monitoringPrimaryHost` option to `modules/flake/allocations.nix` using `serverHostnamesEnum` type
- [x] 1.2 Map `allocations.server.monitoringPrimaryHost` to `server.monitoringPrimaryHost` in `modules/flake/apply/system.nix`
- [x] 1.3 Set `allocations.server.monitoringPrimaryHost = "nixmon"` in `flake/nixos/flake-module.nix`
- [x] 1.4 Add `server.monitoringPrimaryHost` option to `modules/nixos/server/default.nix` (mirroring `ioPrimaryHost`)
- [x] 1.5 Create monitoring helper functions (`isMonitoringPrimaryHost`, `isThisMonitoringPrimaryHost`) in `modules/nixos/server/default.nix` and pass them via `importModule`
- [x] 1.6 Create `modules/nixos/server/monitoring/default.nix` — main entry with options, imports, and `importModule` integration
- [x] 1.7 Create `modules/nixos/server/monitoring/options.nix` — define all `server.monitoring.*` options
- [x] 1.8 Import monitoring module via `importModule ./monitoring {}` in `modules/nixos/server/default.nix`
- [ ] 1.9 Verify all hosts build successfully with the new module structure (no services enabled yet)

## 2. Node Exporter and Promtail (All Hosts)

- [x] 2.1 Create `modules/nixos/server/monitoring/exporters/default.nix` — conditional imports for all exporters
- [x] 2.2 Create `modules/nixos/server/monitoring/exporters/node.nix` — deploy `node_exporter` on port 9100, always enabled when monitoring is on
- [x] 2.3 Create `modules/nixos/server/monitoring/logs/promtail.nix` — deploy Promtail reading journald, shipping to Loki on monitoring primary host
- [ ] 2.4 Verify all hosts build with node_exporter and Promtail configured

## 3. Prometheus Server (Collector Host)

- [x] 3.1 Create `modules/nixos/server/monitoring/collector/default.nix` — conditional imports, only active on monitoring primary host
- [x] 3.2 Create `modules/nixos/server/monitoring/collector/prometheus.nix` — Prometheus server with 90-day retention, 15s scrape interval, auto-discovered scrape targets via `collectAllAttrsFunc`
- [x] 3.3 Define scrape job configurations: node (all hosts), caddy (proxy hosts), postgres (DB host), redis (DB host)
- [ ] 3.4 Verify nixmon builds with Prometheus configured and scrape targets include all servers

## 4. Loki Server (Collector Host)

- [x] 4.1 Create `modules/nixos/server/monitoring/collector/loki.nix` — Loki server with filesystem storage, 90-day retention via compactor
- [ ] 4.2 Verify nixmon builds with Loki configured

## 5. Grafana (Collector Host)

- [x] 5.1 Create `modules/nixos/server/monitoring/collector/grafana.nix` — Grafana server with Kanidm OAuth2, auto-provisioned Prometheus and Loki datasources
- [x] 5.2 Configure Grafana OAuth2 settings: client ID, secret from sops, group-to-role mapping (grafana_admins → Admin, grafana_editors → Editor, default → Viewer)
- [x] 5.3 Add Kanidm `grafana` OAuth2 client provisioning to `hosts/server/nixcloud/identity.nix`
- [ ] 5.4 Verify nixmon builds with Grafana configured

## 6. Caddy Virtual Hosts (Exposure)

- [x] 6.1 Configure Grafana Caddy virtualHost: `grafana.<domain>` with `public = true` (on nixmon via `server.proxy.virtualHosts`)
- [x] 6.2 Configure Prometheus Caddy virtualHost: `prometheus.<domain>` with `public = false` (LAN-only)
- [x] 6.3 Configure Loki Caddy virtualHost: `loki.<domain>` with `public = false` (LAN-only)
- [ ] 6.4 Verify nixmon and nixio (IO primary) build with virtualHost configurations

## 7. Application Exporters

- [x] 7.1 Create `modules/nixos/server/monitoring/exporters/caddy.nix` — enable Caddy metrics endpoint (port 2019), auto-enabled when `server.proxy.virtualHosts` is non-empty
- [x] 7.2 Create `modules/nixos/server/monitoring/exporters/postgres.nix` — deploy `postgres_exporter` on port 9187, auto-enabled when Postgres databases configured
- [x] 7.3 Create `modules/nixos/server/monitoring/exporters/redis.nix` — deploy `redis_exporter` on port 9121, auto-enabled when Redis instances configured
- [ ] 7.4 Verify affected hosts build with application exporters configured

## 8. Proxmox Integration

- [x] 8.1 Create `modules/nixos/server/monitoring/integrations/proxmox.nix` — Proxmox VE exporter on monitoring primary host, credentials from sops
- [x] 8.2 Add Proxmox scrape job to Prometheus configuration
- [x] 8.3 Add sops secret declarations for Proxmox API credentials on nixmon
- [ ] 8.4 Verify nixmon builds with Proxmox exporter configured

## 9. Alerting

- [x] 9.1 Create `modules/nixos/server/monitoring/collector/alerting.nix` — Alertmanager with Home Assistant and Nextcloud Talk webhook receivers
- [x] 9.2 Configure Prometheus alert rules: HostDown, DiskSpaceCritical, HighCPUUsage, HighMemoryUsage
- [x] 9.3 Configure Alertmanager grouping (by host) and repeat interval throttling
- [x] 9.4 Add sops secret declarations for webhook URLs on nixmon
- [x] 9.5 Create `hosts/server/nixcloud/home-assistant/monitoring.nix` — declarative webhook automation for Prometheus alerts
- [x] 9.6 Import `monitoring.nix` in `hosts/server/nixcloud/home-assistant/default.nix`
- [ ] 9.7 Verify nixmon and nixcloud build with alerting configured

## 10. Dashboards

- [x] 10.1 Create `modules/nixos/server/monitoring/collector/dashboards.nix` — Grafana dashboard provisioning
- [x] 10.2 Create or adapt dashboard JSON: Cluster overview
- [ ] 10.3 Create or adapt dashboard JSON: Node metrics (per-host detail)
- [ ] 10.4 Create or adapt dashboard JSON: Application metrics (Caddy, PostgreSQL, Redis)
- [ ] 10.5 Create or adapt dashboard JSON: Proxmox infrastructure
- [x] 10.6 Create or adapt dashboard JSON: Logs explorer
- [ ] 10.7 Verify nixmon builds with dashboard provisioning configured

## 11. Secrets Setup

- [x] 11.1 Add monitoring-related sops secret entries to `hosts/server/nixmon/secrets.yaml` (Kanidm OAuth secret, Proxmox credentials, webhook URLs)
- [x] 11.2 Add any required sops secret entries to `hosts/server/nixcloud/secrets.yaml` if needed for HA integration

## 12. Documentation

- [ ] 12.1 Create `docs/modules/nixos/server/monitoring.md` with option reference, architecture overview, and configuration examples
- [ ] 12.2 Ensure documentation uses placeholder values (no personal info)

## 13. Final Verification

- [ ] 13.1 Run `nix fmt .` on all changed files
- [ ] 13.2 Build all affected server hosts successfully
- [ ] 13.3 Run `nix flake check` with devenv override

## Implementation Notes

**Completed Sections:** Sections 1-9 fully complete; Sections 10-11 partial; Sections 12-13 incomplete.
**Status:** All monitoring module implementations, collector configuration, exporter setup, Grafana OAuth integration, and alerting pipeline are complete. Dashboard provisioning is **partially complete** (only cluster-overview [10.2] and logs-explorer [10.6] implemented; node metrics [10.3], application metrics [10.4], and Proxmox infrastructure [10.5] remain unimplemented). Secrets setup complete for Proxmox and alerting; S3FS credentials added.

**Incomplete Tasks:**

- **Dashboards (Section 10):** Tasks 10.3 (Node metrics), 10.4 (Application metrics), 10.5 (Proxmox infrastructure) remain unchecked and unimplemented. Only 10.1 (provisioning setup), 10.2 (cluster-overview dashboard), and 10.6 (logs-explorer dashboard) are complete. Task 10.7 (build verification) remains unchecked.
- **Build verification tasks** (1.9, 2.4, 3.4, 4.2, 5.4, 6.4, 7.4, 9.7, 10.7, 13.2, 13.3) remain unchecked by user request.
- **Documentation** (12.1, 12.2) remains incomplete by user request.

**Known Issue (Pre-existing):**

- nixarr package build failure is a pre-existing Nixpkgs issue, not related to monitoring module implementation
