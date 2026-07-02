# Server Cluster Monitoring — Observability Stack

## Purpose

The monitoring module provides a comprehensive observability stack for the server
cluster using Prometheus (metrics), Loki (logs), Grafana (visualization), and
Grafana Alloy for authenticated OTLP ingestion.
All components are configured as reusable NixOS modules with automatic
cross-host discovery.

The system consists of three layers:

- **Exporters** (run on all servers)
  - node_exporter for system-level metrics (CPU, memory, disk, network, per-process stats)
  - Grafana Alloy for shipping journald logs and Caddy access logs to Loki
  - **Conditional Exporters**: The following exporters are enabled if their corresponding services are configured on the host:
    - Caddy access logs are parsed and sent to Loki
    - fail2ban exporter available on the IO Coordinator
    - PostgreSQL exporter available on the Database Coordinator
    - Redis exporter available on the Database Coordinator
    - Proxmox exporter available on the Monitoring Coordinator

- **Collectors** (run on the Monitoring Coordinator)
  - Prometheus for metrics aggregation
  - Loki for log aggregation with 90-day retention
  - Alertmanager for alert routing and notifications
  - OTLP/HTTP ingestion on `otlp.<domain>` with bearer-token authentication

- **Visualization** (runs on the Monitoring Coordinator)
  - Grafana with provisioned datasources and dashboards

## Entry Point

- **Main file**: [`modules/nixos/server/monitoring/default.nix`](../../../modules/nixos/server/monitoring/default.nix)

## Architecture / Services / Scope

### Configuration

### Enabling Monitoring

Monitoring is enabled by default on all servers, this can be disabled with `server.monitoring.enable = false`.

##### Options

{{#include ../../generated/server-monitoring-options.md}}

## Secrets

### Declared secrets

| Secret key                              | Purpose                              |
| --------------------------------------- | ------------------------------------ |
| `MONITORING/OLTP/BEARER_TOKEN`          | Bearer token for OTLP HTTP ingestion |
| `MONITORING/GRAFANA/SECRET_KEY`         | Grafana secret key                   |
| `MONITORING/GRAFANA/OAUTH_SECRET`       | Kanidm OAuth2 secret for Grafana     |
| `MONITORING/HOME_ASSISTANT/WEBHOOK_URL` | Home Assistant alert webhook         |
| `MONITORING/NEXTCLOUD_TALK/WEBHOOK_URL` | Nextcloud Talk alert webhook         |
| `PROXMOX/USER`                          | Proxmox metrics user                 |
| `PROXMOX/TOKEN_ID`                      | Proxmox token name                   |
| `PROXMOX/TOKEN_SECRET`                  | Proxmox token secret                 |

### Generating Secrets

Generating secure random secrets can be done with the following command:

```sh
cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 48
```

The `MONITORING/GRAFANA/OAUTH_SECRET` must match the value in `hosts/server/<Application Server>/secrets.yaml` under `KANIDM/OAUTH2/GRAFANA_SECRET` (the Kanidm provisioning side).

### Caddy Virtual Hosts

The module configures four virtual hosts on Monitoring Coordinator:

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

### Alert Rules

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

### Module Structure

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
│   ├── redis.nix            # Redis exporter
│   └── fail2ban.nix         # fail2ban metrics exporter
├── logs/
│   └── alloy.nix            # Alloy log shipping
└── integrations/
    └── proxmox.nix          # PVE exporter for Proxmox API
```

## Operational Notes / Assumptions

### Troubleshooting

### Checking Service Status

On the monitoring host (Monitoring Coordinator):

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
systemctl status prometheus-fail2ban-exporter.service
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

- Verify `GRAFANA_OAUTH_SECRET` in Monitoring Coordinator matches `KANIDM/OAUTH2/GRAFANA_SECRET` in Application Server
- Check Kanidm provisioning has the grafana OAuth2 client configured
- Verify DNS resolves `auth.<domain>` correctly

**Prometheus targets showing as down:**

- Check firewall rules allow traffic on exporter ports from the monitoring host
- Verify the exporter service is running on the target host
- Check network connectivity between Monitoring Coordinator and the target host

**Proxmox metrics missing:**

- Verify `proxmox/token_id` and `proxmox/token_secret` are valid
- Check PVE API is accessible from Monitoring Coordinator: `curl -k https://pve.<domain>/api2/json`
- Review PVE exporter logs: `journalctl -u prometheus-pve-exporter.service`
