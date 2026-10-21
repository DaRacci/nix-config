# Server Cluster Monitoring — Observability Stack

## Purpose

The monitoring module provides a comprehensive observability stack for the server
cluster using Prometheus (metrics), Loki (logs), Grafana (visualisation), and
Grafana Alloy for authenticated OTLP ingestion.
All components are configured as reusable NixOS modules with automatic
cross-host discovery.

The system consists of three layers:

- **Exporters** (run on all servers)

  - `node_exporter` with an explicit, minimal collector profile for system-level metrics
  - NixOS build metadata exported through the `node_exporter` textfile collector
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

- **Visualisation** (runs on the Monitoring Coordinator)

  - Grafana with provisioned datasources and dashboards

## Entry Point

- **Main file**: [`modules/nixos/server/monitoring/default.nix`](../../../modules/nixos/server/monitoring/default.nix)

## Architecture / Services / Scope

### Configuration

### Enabling Monitoring

Monitoring is enabled by default on all servers, this can be disabled with `server.monitoring.enable = false`.

### Options

{{#include ../../generated/server-monitoring-options.md}}

### node_exporter Collector Profile

`node_exporter` runs with `--collector.disable-defaults` and only enables the collectors listed below.
This avoids the upstream default set, which includes many hardware, filesystem, and kernel collectors that are useless or misleading inside an LXC.

| Collector    | Virtual hosts | Physical hosts | Why                                                                                                                             |
| ------------ | ------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `filesystem` | yes           | yes            | Root and bind-mount free space inside the container. The Proxmox exporter reports storage allocation, not per-mount free space. |
| `systemd`    | yes           | yes            | Unit state and failed units inside the container. The host cannot see these.                                                    |
| `cpu`        | no            | yes            | CPU, memory, disk, and network dashboards/alerts use `pve_*` metrics for LXCs. Host metrics still use `node_*`.                 |
| `meminfo`    | no            | yes            | Same as above.                                                                                                                  |
| `netdev`     | no            | yes            | Same as above.                                                                                                                  |
| `diskstats`  | no            | yes            | Per-device I/O on physical hosts. Container I/O comes from `pve_disk_*`.                                                        |
| `loadavg`    | no            | yes            | Host load average. LXC load is host-wide unless `lxcfs` virtualises it.                                                         |
| `pressure`   | no            | yes            | PSI is not reliably namespaced in containers.                                                                                   |
| `stat`       | no            | yes            | Host boot time and context-switch counters.                                                                                     |
| `time`       | no            | yes            | Host clock synchronisation state.                                                                                               |
| `vmstat`     | no            | yes            | Host virtual-memory counters.                                                                                                   |

### NixOS Build Metadata

A oneshot service writes `/var/lib/prometheus-node-exporter/textfile/nixos.prom` before `node_exporter` starts.

The textfile collector exposes:

| Metric                                   | Description                                                                                 |
| ---------------------------------------- | ------------------------------------------------------------------------------------------- |
| `nixos_system_install_timestamp_seconds` | Unix timestamp of the current system activation.                                            |
| `nixos_system_build_info`                | Gauge with `version`, `code_name`, `nixpkgs_revision`, and `configuration_revision` labels. |

## Secrets

### Declared secrets

| Secret key                              | Purpose                                                          |
| --------------------------------------- | ---------------------------------------------------------------- |
| `MONITORING/OLTP/BEARER_TOKEN`          | Bearer token for OTLP HTTP ingestion                             |
| `MONITORING/GRAFANA/SECRET_KEY`         | Grafana secret key                                               |
| `MONITORING/GRAFANA/OAUTH_SECRET`       | Kanidm OAuth2 secret for Grafana                                 |
| `MONITORING/HOME_ASSISTANT/WEBHOOK_URL` | Home Assistant alert webhook                                     |
| `MONITORING/NEXTCLOUD_TALK/WEBHOOK_URL` | Nextcloud Talk alert webhook                                     |
| `MONITORING/ALLOY_DYNAMIC/CA_CERT`      | mTLS CA certificate for the dynamic capture API                  |
| `MONITORING/ALLOY_DYNAMIC/SERVER_CERT`  | mTLS server certificate for the dynamic capture API              |
| `MONITORING/ALLOY_DYNAMIC/SERVER_KEY`   | mTLS server key for the dynamic capture API                      |
| `MONITORING/ALLOY_DYNAMIC/CLIENT_CERT`  | mTLS client certificate used by the Grafana manual-trigger relay |
| `MONITORING/ALLOY_DYNAMIC/CLIENT_KEY`   | mTLS client key used by the Grafana manual-trigger relay         |
| `PROXMOX/USER`                          | Proxmox metrics user                                             |
| `PROXMOX/TOKEN_ID`                      | Proxmox token name                                               |
| `PROXMOX/TOKEN_SECRET`                  | Proxmox token secret                                             |

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
Coordinator's Caddy configuration.

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

- ISO-8601 timestamps with a log level prefix are parsed and normalised

- `detected_level` defaults to `info` when the source log line does not provide one

- Caddy JSON fields `level`, `ts`, `logger`, and `status` are extracted into Loki labels and timestamps

- Caddy access logs are read from `/var/log/caddy-access-*.log` and use the timestamp and level prefix in each line when present

### Log Filtering

Alloy drops journal lines from the units listed in `server.monitoring.logs.dropUnits` before parsing.
The default list targets high-volume application units.
Lines whose detected level is `debug` or `trace` are also _dropped_.

Alloy also rate-limits low-value levels (`info`, `debug`, `trace`) with a hard cap (`server.monitoring.logs.rateLimit`).
This protects the central Loki path when one host gets noisy.

Caddy access logs are a separate `loki.source.file` pipeline and are not affected by these journal filters, so successful requests remain available.

### Dynamic Expanded Capture API (mTLS)

When `server.monitoring.logs.capture.enable = true`, each host exposes an mTLS-protected API to temporarily disable journal drops and rate limits.
This is useful for short incident windows.

- Endpoint: `POST https://<host>:12445/capture`
- Client cert is required and must chain to `MONITORING/ALLOY_DYNAMIC/CA_CERT`
- Optional CN allow-list: `server.monitoring.logs.capture.allowedClientCommonNames`

Example payloads:

```json
{ "action": "enable_extra_capture", "ttl_seconds": 1800 }
```

```json
{ "action": "disable_extra_capture" }
```

Status endpoint:

```sh
curl --cert client.crt --key client.key --cacert ca.crt \
  https://<host>:12445/status
```

### Manual trigger from Grafana

When both of these are enabled on the monitoring coordinator:

- `server.monitoring.logs.capture.enable = true`
- `server.monitoring.logs.capture.relay.enable = true`

A loopback relay service is started and Grafana contact points are provisioned.
The dynamic capture API, relay, and control helper are packaged in `pkgs/alloy-dynamic-capture` and consumed by `modules/nixos/server/monitoring/logs/alloy.nix`:

- `alloy-capture-<host>-enable`
- `alloy-capture-<host>-disable`

You can manually trigger expanded capture from Grafana UI by opening **Alerting → Contact points** and clicking **Test** on the desired contact point.
The relay then calls the host mTLS API and applies the configured TTL.

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

- Verify `MONITORING/GRAFANA/OAUTH_SECRET` in the Monitoring Coordinator matches `KANIDM/OAUTH2/GRAFANA_SECRET` in the Identity Coordinator
- Check Kanidm provisioning has the Grafana OAuth2 client configured
- Verify DNS resolves `auth.<domain>` correctly

**Prometheus targets showing as down:**

- Check firewall rules allow traffic on exporter ports from the monitoring host
- Verify the exporter service is running on the target host
- Check network connectivity between Monitoring Coordinator and the target host

**Proxmox metrics missing:**

- Verify `PROXMOX/TOKEN_ID` and `PROXMOX/TOKEN_SECRET` are valid
- Check PVE API is accessible from Monitoring Coordinator: `curl -k https://pve.<domain>/api2/json`
- Review PVE exporter logs: `journalctl -u prometheus-pve-exporter.service`

## References

- [IO Coordinator](../hosts/server/nixio.md)
- [Monitoring Coordinator](../hosts/server/nixmon.md)
- [Database Coordinator](../hosts/server/nixdb.md)
- [Storage Coordinator](../hosts/server/nixstor.md)
- [Identity Coordinator](../hosts/server/nixauth.md)
