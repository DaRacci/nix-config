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
  - OTLP/HTTP ingestion on `otlp.${server.proxy.domain}` with bearer-token authentication

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

### `node_exporter` Collector Profile

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

| Secret key                              | Purpose                                                   |
| --------------------------------------- | --------------------------------------------------------- |
| `MONITORING/OLTP/BEARER_TOKEN`          | Bearer token for OTLP HTTP ingestion                      |
| `MONITORING/GRAFANA/SECRET_KEY`         | Grafana secret key                                        |
| `MONITORING/GRAFANA/OAUTH_SECRET`       | Kanidm OAuth2 secret for Grafana                          |
| `MONITORING/HOME_ASSISTANT/WEBHOOK_URL` | Home Assistant alert webhook                              |
| `MONITORING/NEXTCLOUD_TALK/WEBHOOK_URL` | Nextcloud Talk alert webhook                              |
| `MONITORING/ALLOY_DYNAMIC/CA_CERT`      | mTLS CA trust bundle for the dynamic capture API          |
| `MONITORING/ALLOY_DYNAMIC/SERVER_CERT`  | mTLS server certificate chain for the dynamic capture API |
| `MONITORING/ALLOY_DYNAMIC/SERVER_KEY`   | mTLS server key for the dynamic capture API               |
| `MONITORING/ALLOY_DYNAMIC/CLIENT_CERT`  | mTLS client certificate chain used by the Grafana relay   |
| `MONITORING/ALLOY_DYNAMIC/CLIENT_KEY`   | mTLS client key used by the Grafana manual-trigger relay  |
| `PROXMOX/USER`                          | Proxmox metrics user                                      |
| `PROXMOX/TOKEN_ID`                      | Proxmox token name                                        |
| `PROXMOX/TOKEN_SECRET`                  | Proxmox token secret                                      |

The `MONITORING/ALLOY_DYNAMIC/*` entries are sops-nix secret names backed by binary files under `hosts/server/<host>/alloy/`.

### Generating Secrets

Generating secure random secrets can be done with the following command:

```sh
cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 48
```

The `MONITORING/GRAFANA/OAUTH_SECRET` must match the value in `hosts/server/<Application Server>/secrets.yaml` under `KANIDM/OAUTH2/GRAFANA_SECRET` (the Kanidm provisioning side).

### mTLS CA scope

The dynamic capture API uses `Alloy Dynamic Capture Intermediate CA`, signed by `Fleet mTLS Root CA`.
See [Internal mTLS CA](../security/internal_mtls_ca.md) for the hierarchy, key custody, rotation, and trust-store policy.

`MONITORING/ALLOY_DYNAMIC/CA_CERT` contains the Fleet root certificate.
The dynamic capture API was never deployed with a legacy CA, so no legacy trust anchors are needed.
`SERVER_CERT` and `CLIENT_CERT` are chains ordered leaf first, then the Alloy intermediate.

### Alloy leaf certificates

Server certificates are valid for two years and include these SANs:

- `DNS:<host>`
- `DNS:<host>.localdomain`
- `DNS:<host>.${server.proxy.domain}`
- `IP:127.0.0.1`

The bare host name is required because the relay connects to `https://<host>:12445`.
`server.proxy.domain` is the fleet's DNS suffix.
Server certificates use `extendedKeyUsage = serverAuth`.
The client certificate uses `commonName = alloy-capture-relay` and `extendedKeyUsage = clientAuth`.

The following assumes `alloy-intermediate.crt` and `alloy-intermediate.key` from the [Internal mTLS CA](../security/internal_mtls_ca.md) procedure.
`<io-primary>` is the host that defines `server.proxy.domain`.

```bash
domain="$(nix eval --raw .#nixosConfigurations.<io-primary>.config.server.proxy.domain)"

for host in nixai nixarr nixcloud nixdev nixio nixmon nixserv; do
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$host.key"
  openssl req -new -key "$host.key" -subj "/CN=$host" -out "$host.csr"
  openssl x509 -req -in "$host.csr" -CA alloy-intermediate.crt -CAkey alloy-intermediate.key \
    -CAcreateserial -days 730 -sha256 -out "$host.crt" -extensions v3 \
    -extfile <(printf '[v3]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\nsubjectAltName=DNS:%s,DNS:%s.localdomain,DNS:%s.%s,IP:127.0.0.1\n' "$host" "$host" "$host" "$domain")
  cat "$host.crt" alloy-intermediate.crt > "$host-chain.crt"
done

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out client.key
openssl req -new -key client.key -subj "/CN=alloy-capture-relay" -out client.csr
openssl x509 -req -in client.csr -CA alloy-intermediate.crt -CAkey alloy-intermediate.key \
  -CAcreateserial -days 730 -sha256 -out client.crt -extensions v3 \
  -extfile <(printf '[v3]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\nsubjectAltName=DNS:alloy-capture-relay\n')
cat client.crt alloy-intermediate.crt > client-chain.crt
```

Store each certificate as a binary SOPS file under the host directory, then encrypt it in place:

```sh
for host in nixai nixarr nixcloud nixdev nixio nixmon nixserv; do
  mkdir -p "hosts/server/$host/alloy"
  cp alloy-trust-bundle.crt "hosts/server/$host/alloy/CA_CERT"
  cp "$host-chain.crt" "hosts/server/$host/alloy/SERVER_CERT"
  cp "$host.key" "hosts/server/$host/alloy/SERVER_KEY"

  sops encrypt --input-type binary --in-place "hosts/server/$host/alloy/CA_CERT"
  sops encrypt --input-type binary --in-place "hosts/server/$host/alloy/SERVER_CERT"
  sops encrypt --input-type binary --in-place "hosts/server/$host/alloy/SERVER_KEY"
done

cp client-chain.crt hosts/server/nixmon/alloy/CLIENT_CERT
cp client.key hosts/server/nixmon/alloy/CLIENT_KEY
sops encrypt --input-type binary --in-place hosts/server/nixmon/alloy/CLIENT_CERT
sops encrypt --input-type binary --in-place hosts/server/nixmon/alloy/CLIENT_KEY
```

`sops` uses the target path to select the `.sops.yaml` recipients.
The encrypted file is a SOPS JSON envelope; `format = "binary"` makes sops-nix decrypt it back to the original PEM.

Only the monitoring host needs the client certificate and key because the relay is gated by `server.monitoring.collector.enable`.
Capture is enabled for all servers in `hosts/server/shared/default.nix` and accepts only client certificates with `CN=alloy-capture-relay`.

### Caddy Virtual Hosts

The module configures four virtual hosts on Monitoring Coordinator:

| Service    | Subdomain                           | Access                        |
| ---------- | ----------------------------------- | ----------------------------- |
| Grafana    | `grafana.${server.proxy.domain}`    | Public                        |
| OTLP       | `otlp.${server.proxy.domain}`       | Public, bearer token required |
| Prometheus | `prometheus.${server.proxy.domain}` | LAN                           |
| Loki       | `loki.${server.proxy.domain}`       | LAN                           |

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

Capture is enabled for all servers by `hosts/server/shared/default.nix`.
Each host exposes an mTLS-protected API to temporarily disable journal drops and rate limits.
This is useful for short incident windows.

- Endpoint: `POST https://<host>:12445/capture`
- Client cert is required and must chain to `MONITORING/ALLOY_DYNAMIC/CA_CERT`
- The configured CN allow-list is `alloy-capture-relay`
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
- Verify DNS resolves `auth.${server.proxy.domain}` correctly

**Prometheus targets showing as down:**

- Check firewall rules allow traffic on exporter ports from the monitoring host
- Verify the exporter service is running on the target host
- Check network connectivity between Monitoring Coordinator and the target host

**Proxmox metrics missing:**

- Verify `PROXMOX/TOKEN_ID` and `PROXMOX/TOKEN_SECRET` are valid
- Check PVE API is accessible from Monitoring Coordinator: `curl -k https://pve.${server.proxy.domain}/api2/json`
- Review PVE exporter logs: `journalctl -u prometheus-pve-exporter.service`

## References

- [IO Coordinator](../hosts/server/nixio.md)
- [Monitoring Coordinator](../hosts/server/nixmon.md)
- [Database Coordinator](../hosts/server/nixdb.md)
- [Storage Coordinator](../hosts/server/nixstor.md)
- [Identity Coordinator](../hosts/server/nixauth.md)
