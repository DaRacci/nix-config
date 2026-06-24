## ADDED Requirements

### Requirement: Per-vhost extension selection

The system SHALL provide `server.proxy.virtualHosts.<name>.extensions` as an option of type `nullOr (listOf str)`. When `null` (default), all globally enabled extensions SHALL apply to the vhost. When set to a list of extension names, only those named extensions SHALL apply.

#### Scenario: Default behavior (all extensions)

- **WHEN** a vhost does not set `extensions` (or sets it to `null`)
- **THEN** all extensions with `enable = true` in the registry SHALL be applied to that vhost

#### Scenario: Explicit extension whitelist

- **WHEN** a vhost sets `extensions = [ "kanidm" ]`
- **THEN** only the "kanidm" extension SHALL be applied to that vhost
- **AND** all other registered extensions SHALL be skipped

#### Scenario: Empty extension list

- **WHEN** a vhost sets `extensions = [ ]`
- **THEN** no extensions SHALL be applied to that vhost

#### Scenario: Invalid extension name in whitelist

- **WHEN** a vhost sets `extensions = [ "nonexistent" ]`
- **THEN** the system SHALL raise an assertion error at evaluation time
