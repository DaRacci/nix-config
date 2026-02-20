## Context

The NixOS server cluster (7 LXC containers on Proxmox: nixai, nixarr, nixcloud, nixdev, nixio, nixmon, nixserv) currently has no centralized monitoring. The only metrics system is `services.metrics` — a Home Assistant Companion (`hacompanion`) module that pushes per-host sensor data directly to HA. This provides basic visibility but lacks historical retention, cross-host correlation, log aggregation, and structured alerting.

The cluster uses a module-based architecture under `modules/nixos/server/` where cross-host configuration discovery is achieved via `importModule` — a function that passes cluster helper functions (`getAllAttrs`, `collectAllAttrs`, `isIOPrimaryHost`, etc.) to sub-modules. This pattern enables any host to declare its capabilities and have the primary host automatically discover and aggregate them (e.g., the proxy module collects `virtualHosts` from all servers; the database module centralizes Postgres/Redis on the IO primary host).

An allocation system in `modules/flake/allocations.nix` designates primary hosts for specific roles (currently `ioPrimaryCoordinator` and `distributedBuilders`), which are mapped to `server.*` options via `modules/flake/apply/system.nix`.

## Goals / Non-Goals

**Goals:**

- Centralized metrics collection (Prometheus) and log aggregation (Loki) on a dedicated host (`nixmon`)
- Unified visualization through Grafana with native Kanidm OAuth2 SSO
- Automatic discovery of all server hosts and their enabled exporters — no per-host manual configuration
- Application-level metrics for Caddy, PostgreSQL, and Redis, auto-enabled based on existing module state
- External infrastructure monitoring (Proxmox API scraping) without modifying the Proxmox host
- Structured alerting to Home Assistant (webhook automation) and Nextcloud Talk (bot webhook)
- 90-day retention for both metrics and logs
- Module design following existing `importModule` + cluster helper patterns

**Non-Goals:**

- Replacing the existing `services.metrics` (hacompanion) module — it serves a different purpose (real-time HA sensors) and will coexist
- Network monitoring (explicitly deferred)
- Distributed Prometheus (federation) or Tempo (tracing)
- Monitoring non-NixOS hosts beyond Proxmox API scraping
- Grafana dashboard auto-generation from enabled services (future enhancement)
- High-availability for the monitoring stack itself

## Decisions

### Decision 1: Monitoring Primary Host as a New Allocation

**Choice:** Add `allocations.server.monitoringPrimaryHost` following the same pattern as `ioPrimaryCoordinator`.

**Rationale:** The collector role (Prometheus, Loki, Grafana, Alertmanager) must run on exactly one host. Using the allocation system keeps this configurable at the flake level and follows established patterns. This also means the monitoring module can use the same `isMonitoringPrimaryHost` helper pattern as `isIOPrimaryHost`.

**Alternatives considered:**

- Hardcoding `nixmon` — breaks the host-agnostic design requirement.
- Reusing `ioPrimaryCoordinator` — conflates two different roles; monitoring and IO are independent concerns.

### Decision 2: Module Architecture with importModule

**Choice:** Use the existing `importModule` pattern but extend the cluster helpers with monitoring-specific functions (`isMonitoringPrimaryHost`, `isThisMonitoringPrimaryHost`).

**Rationale:** The monitoring module needs both the existing cluster helpers (to discover all server configs, their proxy/database settings) AND new helpers specific to monitoring role detection. Adding a `monitoringPrimaryHost` option to `server.*` and deriving helpers from it mirrors the exact pattern used by `ioPrimaryHost`.

**Structure:**

- `monitoring/default.nix` — defines options, adds `isMonitoringPrimaryHost` helpers, imports sub-modules
- `monitoring/collector/` — conditionally enabled on the monitoring primary host only
- `monitoring/exporters/` — enabled on all hosts where `server.monitoring.enable = true`
- `monitoring/logs/` — Promtail on all hosts
- `monitoring/integrations/` — Proxmox exporter on monitoring primary host

### Decision 3: Scrape Target Discovery via collectAllAttrs

**Choice:** Each host declares its exporter endpoints via `server.monitoring.exporters.*` options. The monitoring primary host uses `collectAllAttrsFunc` to discover all targets and build Prometheus scrape configs.

**Rationale:** This is the exact pattern used by the proxy module (collecting `virtualHosts` from all servers) and the database module. It means adding a new server automatically makes it a scrape target — zero manual configuration.

**How it works:**

1. Every host with `server.monitoring.enable = true` gets `node_exporter` and `promtail` enabled
1. If `server.proxy.virtualHosts != {}`, the Caddy exporter is auto-enabled
1. If `server.database.postgres.databases != {}`, the Postgres exporter is auto-enabled
1. If `server.database.redis.instances != {}`, the Redis exporter is auto-enabled
1. On the monitoring primary host, `collectAllAttrsFunc` iterates all server configs to build scrape target lists

### Decision 4: Grafana with Native Kanidm OAuth2 (not Caddy SSO)

**Choice:** Use Grafana's built-in OAuth2/OIDC provider pointing at Kanidm, with group-based role mapping.

**Rationale:** Grafana has first-class OAuth2 support with role mapping from identity provider groups. This provides a better UX than Caddy forward-auth (which can't map groups to Grafana roles) and keeps auth state within Grafana itself.

**Configuration:**

- Kanidm OAuth2 client provisioned via existing system in `hosts/server/nixcloud/identity.nix`
- Groups: `grafana_admins` → Admin role, `grafana_editors` → Editor role, default → Viewer
- OAuth2 secret stored in sops and referenced by Grafana config on nixmon

### Decision 5: LAN-Only Access for Prometheus and Loki

**Choice:** Expose Prometheus and Loki as Caddy virtualHosts with `public = false` (which applies LAN-only iptables restrictions via the existing proxy module).

**Rationale:** These services expose raw data and have no authentication. The proxy module's existing `public` flag mechanism handles LAN restriction via iptables — no new infrastructure needed.

### Decision 6: Alerting via Alertmanager Webhook Receivers

**Choice:** Alertmanager with two webhook receivers: one for Home Assistant (declarative NixOS webhook automation) and one for Nextcloud Talk (existing bot token).

**Rationale:** Both targets accept HTTP webhooks. Alertmanager's routing and grouping prevents alert storms. The HA webhook automation is fully declarative in NixOS config, avoiding manual HA UI configuration.

**Alternatives considered:**

- Direct Prometheus alerting → no grouping, throttling, or silence support.
- Grafana alerting → would couple visualization to alerting; Alertmanager is the standard approach.

### Decision 7: Retention at Application Level

**Choice:** Configure 90-day retention in Prometheus (`--storage.tsdb.retention.time=90d`) and Loki (retention via compactor with `retention_period: 90d`).

**Rationale:** Simple, declarative, and matches user requirement exactly. Disk usage is manageable for 7 servers with 15s scrape intervals — estimated ~2-5GB for Prometheus, ~5-10GB for Loki at 90 days.

## Risks / Trade-offs

**[Single point of failure]** → All monitoring on one host (nixmon). If nixmon goes down, monitoring is blind.
*Mitigation:* This is acceptable for the current cluster size. Future enhancement could add federation or remote-write replication.

**[Prometheus memory usage]** → With all exporters and 15s scrape interval across 7 hosts, Prometheus may use 500MB-1GB RAM.
*Mitigation:* nixmon is a dedicated LXC container; resource limits can be tuned. Monitor Prometheus's own metrics.

**[Kanidm OAuth2 secret distribution]** → The OAuth2 client secret generated on nixcloud must be available on nixmon for Grafana.
*Mitigation:* Use sops-nix. After initial Kanidm provisioning, retrieve the secret and add to nixmon's secrets.yaml. This is a one-time manual step documented in the proposal.

**[Proxmox API availability]** → If Proxmox API is unreachable, the exporter will report errors, potentially triggering spurious alerts.
*Mitigation:* Configure a dedicated Alertmanager inhibition rule that suppresses Proxmox-related alerts when the API target is down.

**[Existing hacompanion overlap]** → Some metrics (CPU, memory, uptime) will be collected by both node_exporter and hacompanion.
*Mitigation:* These serve different purposes — Prometheus for historical analysis and alerting, hacompanion for real-time HA dashboard. No conflict, but document the overlap.

## Migration Plan

This is a greenfield addition — no existing monitoring to migrate from.

**Deployment order:**

1. Deploy allocation changes and monitoring module options (no services yet) — all hosts rebuild cleanly
1. Enable exporters (node_exporter, promtail) on all hosts — lightweight, no disruption
1. Deploy collector stack (Prometheus, Loki, Grafana) on nixmon
1. Add application exporters (Caddy, Postgres, Redis) — auto-discovered by collector
1. Add Proxmox integration
1. Add Kanidm OAuth2 provisioning and configure Grafana auth
1. Enable alerting (Alertmanager + webhook receivers)
1. Provision dashboards

**Rollback:** Disable `server.monitoring.enable` on all hosts or just the collector. Exporters are lightweight and harmless to leave running.

## Open Questions

1. **Proxmox exporter package**: Need to verify `prometheus-pve-exporter` is available in nixpkgs, or if a custom package/overlay is needed.
1. **Nextcloud Talk webhook format**: Need to confirm the exact API endpoint format and whether the bot token goes in the URL or as a header.
1. **Grafana provisioning format**: Dashboards can be provisioned as JSON files — need to decide whether to write them from scratch or adapt community dashboards (Node Exporter Full, etc.).
