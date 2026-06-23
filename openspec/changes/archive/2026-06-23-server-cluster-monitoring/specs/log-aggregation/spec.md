## ADDED Requirements

### Requirement: Loki server runs on monitoring primary host

The system SHALL deploy a Loki server on the host designated as `monitoringPrimaryHost`. The server SHALL be configured with 90-day log retention and filesystem-based storage.

#### Scenario: Loki deployed on monitoring primary host

- **WHEN** a host is designated as `monitoringPrimaryHost`
- **THEN** Loki SHALL be running and accepting log pushes on port 3100 on that host

#### Scenario: Loki retention configured

- **WHEN** the Loki server is running
- **THEN** the retention period SHALL be set to 90 days via the compactor

### Requirement: Promtail runs on all monitored servers

The system SHALL deploy Promtail on every server where `server.monitoring.enable` is true. Promtail SHALL read from systemd journald and ship logs to the Loki server on the monitoring primary host.

#### Scenario: Promtail auto-enabled on monitored servers

- **WHEN** a server has `server.monitoring.enable = true`
- **THEN** Promtail SHALL be running and shipping journald logs to the Loki endpoint on the monitoring primary host

#### Scenario: Promtail labels logs with host identity

- **WHEN** Promtail ships logs to Loki
- **THEN** each log entry SHALL include labels for `host` (hostname), `job` (service/unit name), and `__host__` (source identifier)

#### Scenario: Promtail not running when monitoring disabled

- **WHEN** a server has `server.monitoring.enable = false`
- **THEN** Promtail SHALL NOT be running on that server

### Requirement: Log discovery follows cluster auto-discovery

The system SHALL automatically configure Promtail on new servers added to the cluster. No manual Loki or Promtail configuration changes are needed on any host.

#### Scenario: New server automatically ships logs

- **WHEN** a new server is added to the cluster with `server.monitoring.enable = true`
- **THEN** Promtail SHALL be configured on the new server to push logs to Loki
- **AND** Loki SHALL accept and index logs from the new server without configuration changes
