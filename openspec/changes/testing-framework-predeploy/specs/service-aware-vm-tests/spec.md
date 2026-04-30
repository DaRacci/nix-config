## ADDED Requirements

### Requirement: Every server host gets baseline VM assertions

The system SHALL apply a baseline VM test to every server host that verifies boot success, multi-user readiness, SSH availability, firewall state, journald persistence, and absence of unexpected failed units.

#### Scenario: Baseline assertions run for any server host
- **WHEN** a server host VM test is executed
- **THEN** the test SHALL verify the baseline system assertions for that host

### Requirement: Service-specific checks are auto-selected from host configuration

The system SHALL attach service-specific VM tests based on evaluated configuration state rather than static hostname mappings.

#### Scenario: Postgres test selected when postgres is configured
- **WHEN** a host configuration includes postgres-related server state
- **THEN** the VM test for that host SHALL include postgres-specific verification

#### Scenario: Proxy test selected when virtual hosts exist
- **WHEN** a host configuration has `server.proxy.virtualHosts`
- **THEN** the VM test for that host SHALL include proxy or HTTP reachability checks

#### Scenario: Monitoring collector checks selected when collector is enabled
- **WHEN** a host configuration enables the monitoring collector role
- **THEN** the VM test for that host SHALL include monitoring service reachability checks

#### Scenario: Tailscale check selected when tailscale is enabled
- **WHEN** a host configuration enables `services.tailscale`
- **THEN** the VM test for that host SHALL verify the tailscaled unit is active

### Requirement: Single-host VM tests can start required local dependencies

The system SHALL allow test-only local enablement of dependent services inside a single VM when that is necessary to validate host behavior without a multi-node cluster.

#### Scenario: Local service started for validation
- **WHEN** a host's production behavior depends on a service that would otherwise live on another node
- **THEN** the VM test setup SHALL be able to start that service locally for the duration of the single-host test
- **AND** SHALL NOT alter production cluster logic to do so
