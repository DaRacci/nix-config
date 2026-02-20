## ADDED Requirements

### Requirement: Alertmanager runs on monitoring primary host

The system SHALL deploy Alertmanager on the monitoring primary host, configured to receive alerts from Prometheus and route them to webhook receivers.

#### Scenario: Alertmanager running and connected to Prometheus

- **WHEN** the monitoring collector is enabled
- **THEN** Alertmanager SHALL be running on port 9093
- **AND** Prometheus SHALL be configured to send alerts to Alertmanager

### Requirement: Home Assistant webhook receiver

The system SHALL configure an Alertmanager webhook receiver that sends alerts to a Home Assistant webhook endpoint. The webhook URL SHALL be stored in sops secrets.

#### Scenario: Alert delivered to Home Assistant

- **WHEN** a Prometheus alert fires
- **AND** the alert matches the Home Assistant routing rule
- **THEN** Alertmanager SHALL POST the alert payload to the Home Assistant webhook URL

### Requirement: Declarative Home Assistant webhook automation

The system SHALL create a declarative Home Assistant automation in `hosts/server/nixcloud/home-assistant/monitoring.nix` that processes incoming Prometheus webhook alerts and triggers notifications.

#### Scenario: Home Assistant automation exists

- **WHEN** the Home Assistant configuration is built on nixcloud
- **THEN** a webhook automation for `prometheus_alerts` SHALL be configured declaratively

#### Scenario: Home Assistant processes alert webhook

- **WHEN** Alertmanager sends a POST to the Home Assistant webhook
- **THEN** Home Assistant SHALL trigger the monitoring automation and create a notification

### Requirement: Nextcloud Talk webhook receiver

The system SHALL configure an Alertmanager webhook receiver that sends alerts to a Nextcloud Talk bot endpoint. The bot token/URL SHALL be stored in sops secrets.

#### Scenario: Alert delivered to Nextcloud Talk

- **WHEN** a Prometheus alert fires
- **AND** the alert matches the Nextcloud Talk routing rule
- **THEN** Alertmanager SHALL POST a formatted message to the Nextcloud Talk bot webhook

### Requirement: Basic alert rules defined

The system SHALL include a baseline set of alert rules for common failure conditions: host down, high CPU usage, high memory usage, disk space critical, and service down.

#### Scenario: Host down alert fires

- **WHEN** a monitored server's node_exporter becomes unreachable for more than 2 minutes
- **THEN** a `HostDown` alert SHALL fire in Prometheus

#### Scenario: Disk space critical alert fires

- **WHEN** a server's root filesystem usage exceeds 90%
- **THEN** a `DiskSpaceCritical` alert SHALL fire in Prometheus

#### Scenario: High CPU alert fires

- **WHEN** a server's CPU usage exceeds 90% for more than 5 minutes
- **THEN** a `HighCPUUsage` alert SHALL fire in Prometheus

#### Scenario: High memory alert fires

- **WHEN** a server's memory usage exceeds 90% for more than 5 minutes
- **THEN** a `HighMemoryUsage` alert SHALL fire in Prometheus

#### Scenario: Service down alert fires

- **WHEN** a monitored service target (non-node job) becomes unreachable for more than 2 minutes
- **THEN** a `ServiceDown` alert SHALL fire in Prometheus with the job and instance labels identifying the affected service

### Requirement: Alert grouping and throttling

Alertmanager SHALL group related alerts and enforce a minimum interval between repeated notifications to prevent alert storms.

#### Scenario: Alerts grouped by host

- **WHEN** multiple alerts fire for the same host simultaneously
- **THEN** Alertmanager SHALL group them into a single notification

#### Scenario: Repeated alerts throttled

- **WHEN** the same alert remains firing
- **THEN** Alertmanager SHALL NOT send repeat notifications more frequently than the configured repeat interval
