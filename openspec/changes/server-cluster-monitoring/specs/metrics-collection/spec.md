## ADDED Requirements

### Requirement: Prometheus server runs on monitoring primary host

The system SHALL deploy a Prometheus server on the host designated as `monitoringPrimaryHost` in the flake allocations. The server SHALL be configured with 90-day data retention and a 15-second global scrape interval.

#### Scenario: Prometheus deployed on monitoring primary host

- **WHEN** a host is designated as `monitoringPrimaryHost` in allocations
- **THEN** Prometheus SHALL be running and listening on port 9090 on that host

#### Scenario: Prometheus retention configured

- **WHEN** the Prometheus server is running
- **THEN** the TSDB retention period SHALL be set to 90 days

### Requirement: Node exporter runs on all monitored servers

The system SHALL deploy `node_exporter` on every server where `server.monitoring.enable` is true. The exporter SHALL expose system-level metrics (CPU, memory, disk, network) on port 9100.

#### Scenario: Node exporter auto-enabled

- **WHEN** a server has `server.monitoring.enable = true` (the default)
- **THEN** `node_exporter` SHALL be running on port 9100 on that server

#### Scenario: Node exporter disabled

- **WHEN** a server has `server.monitoring.enable = false`
- **THEN** `node_exporter` SHALL NOT be running on that server

### Requirement: Caddy metrics auto-enabled when proxy is active

The system SHALL auto-enable Caddy metrics exposure on any server that has `server.proxy.virtualHosts` configured (non-empty). The Caddy admin API metrics endpoint SHALL be scraped by Prometheus.

#### Scenario: Caddy metrics enabled when proxy has virtualHosts

- **WHEN** a server has `server.proxy.virtualHosts` with at least one entry
- **THEN** Caddy's metrics endpoint SHALL be enabled on port 2019
- **AND** Prometheus SHALL have a scrape target for that host's Caddy metrics

#### Scenario: Caddy metrics not enabled without proxy

- **WHEN** a server has no `server.proxy.virtualHosts` configured
- **THEN** Caddy metrics SHALL NOT be enabled on that server

### Requirement: PostgreSQL exporter auto-enabled when databases are configured

The system SHALL auto-enable `postgres_exporter` on the database primary host when PostgreSQL databases are configured via the server database module.

#### Scenario: PostgreSQL exporter enabled on database host

- **WHEN** PostgreSQL databases are configured via `server.database.postgres`
- **THEN** `postgres_exporter` SHALL be running on port 9187 on the IO primary host
- **AND** Prometheus SHALL have a scrape target for PostgreSQL metrics

### Requirement: Redis exporter auto-enabled when Redis instances exist

The system SHALL auto-enable `redis_exporter` on the database primary host when Redis instances are configured via the server database module.

#### Scenario: Redis exporter enabled on database host

- **WHEN** Redis instances are configured via `server.database.redis`
- **THEN** `redis_exporter` SHALL be running on port 9121 on the IO primary host
- **AND** Prometheus SHALL have a scrape target for Redis metrics

### Requirement: Prometheus auto-discovers all server scrape targets

The system SHALL use cluster helper functions (`collectAllAttrsFunc`) to automatically build Prometheus scrape configurations from all servers in the cluster. Adding a new server SHALL automatically include it in monitoring without manual configuration.

#### Scenario: New server automatically discovered

- **WHEN** a new server is added to the cluster with `server.monitoring.enable = true`
- **THEN** Prometheus scrape configs SHALL include the new server's node_exporter target
- **AND** no manual changes to the monitoring primary host configuration are required

#### Scenario: Scrape configs reflect actual enabled exporters

- **WHEN** a server has specific exporters enabled (e.g., Caddy, Postgres)
- **THEN** Prometheus SHALL have scrape targets for each enabled exporter on that server
- **AND** SHALL NOT have targets for disabled exporters
