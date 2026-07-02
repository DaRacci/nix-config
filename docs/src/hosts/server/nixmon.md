# nixmon — Monitoring

## Purpose

`nixmon` is the monitoring primary host for the cluster.
It runs the observability stack of metrics, logs, alerting, and dashboards.

## Entry Point

- **Main file**: [`hosts/server/nixmon/default.nix`](../../../../hosts/server/nixmon/default.nix)

## Architecture / Services / Scope

### Uptime Monitoring

- **Uptime Kuma**: Service status monitoring.

### Observability Stack

As the `monitoringPrimaryHost`, `nixmon` runs the collector services defined by the [Server Monitoring](../../components/server_monitoring.md).

## Secrets

### Declared secrets

| Secret key                              | Purpose                            |
| --------------------------------------- | ---------------------------------- |
| `MONITORING/OLTP/BEARER_TOKEN`          | Bearer token for OTLP ingestion    |
| `MONITORING/GRAFANA/SECRET_KEY`         | Grafana session secret             |
| `MONITORING/GRAFANA/OAUTH_SECRET`       | Kanidm OAuth2 secret for Grafana   |
| `MONITORING/HOME_ASSISTANT/WEBHOOK_URL` | Home Assistant alert webhook       |
| `MONITORING/NEXTCLOUD_TALK/WEBHOOK_URL` | Nextcloud Talk alert webhook       |
| `MONITORING/MINIO_PROMETHEUS_TOKEN`     | Prometheus token for MinIO metrics |
| `PROXMOX/USER`                          | Proxmox API user                   |
| `PROXMOX/TOKEN_ID`                      | Proxmox API token ID               |
| `PROXMOX/TOKEN_SECRET`                  | Proxmox API token secret           |
| `S3FS_AUTH/LOKI`                        | S3 credentials for Loki storage    |

## Operational Notes / Assumptions

- Grafana requires a matching `KANIDM/OAUTH2/GRAFANA_SECRET` in the Identity Coordinator's provisioning so the OAuth2 client works.
- Monitoring web UIs are exposed through the IO Coordinator reverse proxy.

## References

- [Server Monitoring](../../components/server_monitoring.md)
- [Identity Coordinator](../../hosts/server/nixauth.md)
- [IO Coordinator](../../hosts/server/nixio.md)
