# Server Cluster Monitoring

The monitoring module provides a comprehensive observability stack for the server
cluster using Prometheus (metrics), Loki (logs), Grafana (visualization), and
Grafana Alloy for authenticated OTLP ingestion.
All components are configured as reusable NixOS modules with automatic
cross-host discovery.

## Overview

The system consists of three layers:

1. **Exporters** (run on all servers)
   - node_exporter for system-level metrics (CPU, memory, disk, network, per-process stats)
   - Grafana Alloy for shipping journald logs and Caddy access logs to Loki
   - Caddy access logs are parsed as JSON at ingest time so `detected_level`, `logger`, and `status` are available in Loki
   - Ingest-time log parsing for journal `stdout` entries and Caddy access logs to infer `detected_level` and normalize common timestamp formats
   - Application-specific exporters (Caddy, PostgreSQL, Redis) enabled automatically

1. **Collectors** (run on the monitoring primary host)
   - Prometheus for metrics aggregation with 90-day retention
   - Loki for log aggregation with 90-day retention
   - Alertmanager for alert routing and notifications
   - OTLP/HTTP ingestion on `otlp.<domain>` with bearer-token authentication

1. **Visualization** (runs on the monitoring primary host)
   - Grafana with provisioned datasources and dashboards
   - Native Kanidm OAuth2 authentication

## Architecture

```text
┌─────────────────────────────────────────────────────┐
│                    nixmon (Monitoring Primary)      │
│  ┌──────────┐  ┌──────┐  ┌─────────┐  ┌──────────┐  │
│  │Prometheus│  │ Loki │  │ Grafana │  │Alertmgr  │  │
│  │  :9090   │  │:3100 │  │  :3000  │  │  :9093   │  │
│  └────┬──┬──┘  └──┬───┘  └─────────┘  └────┬─────┘  │
│       │  │        │                        │        │
│  ┌────┘  │   ┌────┘        ┌───────────────┘        │
│  │ scrape│   │ push        │ webhooks               │
├──┼───────┼───┼─────────────┼────────────────────────┤
│  ▼       ▼   ▼             ▼                        │
│  All servers:          Home Assistant / Nextcloud   │
│  - node_exporter :9100                              │
│  - alloy → Loki                                     │
│  - OTLP/HTTP → Alloy :4318                          │
│  - caddy metrics :2019 (if proxy configured)        │
│  - postgres_exporter :9187 (if postgres configured) │
│  - redis_exporter :9121 (if redis configured)       │
│  - pve_exporter :9221 (nixmon only, Proxmox API)    │
└─────────────────────────────────────────────────────┘
```

## Configuration

### Enabling Monitoring

Monitoring is enabled by default on all servers (`server.monitoring.enable = true`).
The monitoring primary host is configured via the `allocations.server.monitoringPrimaryHost`
option, currently set to `nixmon`.

### Options

{{#include ../generated/server-monitoring-options.md}}

### Auto-Detection

The module automatically detects and enables exporters based on host role:

- **Caddy exporter**: Enabled when `server.proxy.virtualHosts` is non-empty
- **PostgreSQL exporter**: Enabled on the IO primary host when postgres databases are configured
- **Redis exporter**: Enabled on the IO primary host when redis instances are configured
- **Caddy access logs**: Enabled when Caddy metrics/logs are enabled; each access log file under `/var/log/caddy-access-*` is shipped to Loki and parsed as JSON
- **node_exporter process collector**: Enabled on all servers via the `processes` collector to expose per-process stats
- **Collector services**: Enabled only on the monitoring primary host

## Secrets

The monitoring module requires the following secrets in `hosts/server/nixmon/secrets.yaml`:

```yaml
MONITORING:
  OLTP:
    BEARER_TOKEN: <random-secret-key>
  GRAFANA:
    SECRET_KEY: <random-secret-key>
    OAUTH_SECRET: <kanidm-oauth2-secret>
  HOME_ASSISTANT:
    WEBHOOK_URL: <ha-webhook-url>
  NEXTCLOUD_TALK:
    WEBHOOK_URL: <nc-talk-webhook-url>
PROXMOX:
  USER: <proxmox-user-at-realm>
  TOKEN_ID: <proxmox-token-name>
  TOKEN_SECRET: <proxmox-token-secret>
```

### Generating Secrets

Generating secure random secrets can be done with the following command:

```sh
cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 48
```

The `MONITORING/GRAFANA/OAUTH_SECRET` must match the value in `hosts/server/nixcloud/secrets.yaml`
under `KANIDM/OAUTH2/GRAFANA_SECRET` (the Kanidm provisioning side).

## Caddy Virtual Hosts

The module configures four virtual hosts on nixmon:

| Service    | Subdomain             | Access                        |
| ---------- | --------------------- | ----------------------------- |
| Grafana    | `grafana.<domain>`    | Public                        |
| OTLP       | `otlp.<domain>`       | Public, bearer token required |
| Prometheus | `prometheus.<domain>` | LAN                           |
| Loki       | `loki.<domain>`       | LAN                           |

Grafana remains protected by the existing Kanidm-backed login flow. The OTLP
ingestion endpoint is intended for machine-to-machine clients and requires an
`Authorization: Bearer <token>` header on every request. The exposed OTLP/HTTP
paths are the standard `/v1/metrics` and `/v1/logs` endpoints.

These are defined in `hosts/server/nixmon/default.nix` and collected by the IO
primary host's Caddy configuration.

## Alert Rules

The following alerts are configured by default:

| Alert               | Condition                                | Severity |
| ------------------- | ---------------------------------------- | -------- |
| `HostDown`          | `up{job="node"} == 0` for 2 minutes      | Critical |
| `DiskSpaceCritical` | Root filesystem < 10% free for 5 minutes | Critical |
| `HighCPUUsage`      | CPU usage > 90% for 5 minutes            | Warning  |
| `HighMemoryUsage`   | Memory usage > 90% for 5 minutes         | Warning  |
| `ServiceDown`       | `up{job!="node"} == 0` for 2 minutes     | Critical |

Alerts are routed to:

- **Home Assistant**: All critical and warning alerts via webhook (requires `collector.alerting.homeAssistant.enable = true`)
- **Nextcloud Talk**: Critical alerts only via webhook (requires `collector.alerting.nextcloudTalk.enable = true`)

## Module Structure

```text
modules/nixos/server/monitoring/
├── default.nix              # Entry point, imports sub-modules
├── options.nix              # All server.monitoring.* options
├── collector/
│   ├── default.nix          # Imports collector sub-modules
│   ├── prometheus.nix       # Prometheus server + scrape targets
│   ├── loki.nix             # Loki server + storage config
│   ├── grafana.nix          # Grafana + Kanidm OAuth2
│   ├── otlp.nix             # OTLP ingestion
│   ├── alerting.nix         # Alertmanager + alert rules
│   └── dashboards.nix       # Dashboard provisioning
├── exporters/
│   ├── default.nix          # Imports exporter sub-modules
│   ├── node.nix             # node_exporter
│   ├── caddy.nix            # Caddy metrics
│   ├── postgres.nix         # PostgreSQL exporter
│   └── redis.nix            # Redis exporter
├── logs/
│   └── alloy.nix            # Alloy log shipping
└── integrations/
    └── proxmox.nix          # PVE exporter for Proxmox API
```

## Troubleshooting

### Checking Service Status

On the monitoring host (nixmon):

```sh
systemctl status prometheus.service
systemctl status loki.service
systemctl status grafana.service
systemctl status prometheus-alertmanager.service
systemctl status prometheus-pve-exporter.service
```

On any server:

```sh
systemctl status prometheus-node-exporter.service
systemctl status alloy.service
```

### Verifying Metrics Collection

Check Prometheus targets are up:

```sh
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health: .health}'
```

### Verifying Log Collection

Alloy applies ingest-time parsing for journal `stdout` logs and Caddy access logs before forwarding to Loki:

- Caddy access logs are read as JSON, not plain text

- Legacy timestamps in form `YYYY/MM/DD HH:MM:SS` are parsed and used as event timestamps

- ISO-8601 timestamps with a log level prefix are parsed and normalized

- `detected_level` defaults to `info` when the source log line does not provide one

- Caddy JSON fields `level`, `ts`, `logger`, and `status` are extracted into Loki labels and timestamps

- Caddy access logs are read from `/var/log/caddy-access-*.log` and use the timestamp and level prefix in each line when present

node_exporter also enables the `processes` collector, which exposes per-process metrics such as CPU and memory usage for running processes.

Check Alloy is shipping logs:

```sh
journalctl -u alloy.service -f
```

Query Loki directly:

```sh
curl -s 'http://localhost:3100/loki/api/v1/labels' | jq
```

### Common Issues

**Grafana OAuth login fails:**

- Verify `GRAFANA_OAUTH_SECRET` in nixmon matches `KANIDM/OAUTH2/GRAFANA_SECRET` in nixcloud
- Check Kanidm provisioning has the grafana OAuth2 client configured
- Verify DNS resolves `auth.<domain>` correctly

**Prometheus targets showing as down:**

- Check firewall rules allow traffic on exporter ports from the monitoring host
- Verify the exporter service is running on the target host
- Check network connectivity between nixmon and the target host

**Proxmox metrics missing:**

- Verify `proxmox/token_id` and `proxmox/token_secret` are valid
- Check PVE API is accessible from nixmon: `curl -k https://pve.<domain>/api2/json`
- Review PVE exporter logs: `journalctl -u prometheus-pve-exporter.service`
