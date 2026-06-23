## ADDED Requirements

### Requirement: Proxmox exporter runs on monitoring primary host

The system SHALL deploy a Proxmox VE exporter on the monitoring primary host that scrapes the Proxmox API for host, VM/container, and storage metrics.

#### Scenario: Proxmox exporter running when enabled

- **WHEN** `server.monitoring.collector.proxmox.enable` is true
- **THEN** the Proxmox exporter SHALL be running on the monitoring primary host
- **AND** Prometheus SHALL have a scrape target for the Proxmox exporter

#### Scenario: Proxmox exporter not running when disabled

- **WHEN** `server.monitoring.collector.proxmox.enable` is false
- **THEN** the Proxmox exporter SHALL NOT be running

### Requirement: Proxmox API credentials from sops secrets

The system SHALL read Proxmox API URL, token ID, and token secret from sops-encrypted secrets. No credentials SHALL be hardcoded in Nix configuration.

#### Scenario: Credentials loaded from sops

- **WHEN** the Proxmox exporter starts
- **THEN** it SHALL read API credentials from sops secret files
- **AND** the credentials SHALL NOT appear in the Nix store or system configuration

### Requirement: Proxmox metrics cover host, containers, and storage

The system SHALL expose Proxmox metrics including node-level statistics (CPU, memory, network), per-VM/container status and resource usage, and storage pool utilization.

#### Scenario: Proxmox node metrics available

- **WHEN** Prometheus scrapes the Proxmox exporter
- **THEN** node-level CPU, memory, and network metrics SHALL be available

#### Scenario: Proxmox container metrics available

- **WHEN** Prometheus scrapes the Proxmox exporter
- **THEN** per-container status and resource usage metrics SHALL be available

#### Scenario: Proxmox storage metrics available

- **WHEN** Prometheus scrapes the Proxmox exporter
- **THEN** storage pool usage and availability metrics SHALL be available
