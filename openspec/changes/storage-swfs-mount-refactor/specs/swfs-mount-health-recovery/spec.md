## ADDED Requirements

### Requirement: Storage mounts expose automated health checks
The system SHALL generate systemd-managed health-check behavior for `server.storage.swfsMount` entries so mounts can be probed after boot.

#### Scenario: Health-check units are generated
- **WHEN** a storage mount entry is evaluated
- **THEN** the system SHALL generate a check mechanism that probes the mounted path on a schedule or equivalent systemd-managed cadence

#### Scenario: Health-check probe is bounded
- **WHEN** the mount health probe runs
- **THEN** the probe SHALL use a bounded check strategy so a hung FUSE mount does not block the checker indefinitely

### Requirement: Broken mounts are remediated automatically
The system SHALL attempt backend-aware recovery when a mount health probe fails.

#### Scenario: Failed MinIO-backed mount is remounted
- **WHEN** a MinIO-backed mount fails its health probe
- **THEN** the system SHALL detach the stale FUSE mount if necessary and restart the corresponding MinIO-backed mount unit

#### Scenario: Failed SeaweedFS-backed mount is remounted
- **WHEN** a SeaweedFS-backed mount fails its health probe
- **THEN** the system SHALL detach the stale FUSE mount if necessary and restart the corresponding `weed mount` service

### Requirement: Recovery behavior is configurable per mount
The system SHALL allow mount entries to control whether automated health recovery is enabled and how frequently it runs.

#### Scenario: Mount-specific check policy is configured
- **WHEN** a maintainer configures health-check policy for a mount entry
- **THEN** the generated systemd recovery behavior SHALL use that mount entry’s configured enablement and interval settings

### Requirement: Recovery behavior includes service management
The system SHALL expose options to define services that need to be reloaded or restarted.

#### Scenario: Recovery is required
- **WHEN** a recovery action is triggered for a mount entry
- **THEN** the system SHALL reload or restart any services specified in that mount entry's recovery configuration after remediating the mount
- **WHEN** a mount entry does not specify any services to manage on recovery
- **THEN** the system SHALL only attempt to remediate the mount without reloading or restarting any additional services
