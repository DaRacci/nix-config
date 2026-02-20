## ADDED Requirements

### Requirement: Monitoring primary host allocation option

The system SHALL add a `monitoringPrimaryHost` option to `allocations.server` in `modules/flake/allocations.nix`, using the same `serverHostnamesEnum` type as `ioPrimaryCoordinator`.

#### Scenario: Allocation option available

- **WHEN** the flake is evaluated
- **THEN** `allocations.server.monitoringPrimaryHost` SHALL be a configurable option accepting any server hostname

#### Scenario: Allocation mapped to server module

- **WHEN** `allocations.server.monitoringPrimaryHost` is set
- **THEN** the value SHALL be mapped to `server.monitoringPrimaryHost` on all server hosts via `modules/flake/apply/system.nix`

### Requirement: Monitoring module uses importModule pattern

The system SHALL implement the monitoring module using the `importModule` pattern from `modules/nixos/server/default.nix`, receiving all cluster helper functions as arguments.

#### Scenario: Module receives cluster helpers

- **WHEN** the monitoring module is imported via `importModule`
- **THEN** it SHALL have access to `collectAllAttrsFunc`, `getAllAttrs`, `isIOPrimaryHost`, `serverConfigurations`, and all other cluster helper functions

#### Scenario: Module imported in server default.nix

- **WHEN** the server module loads
- **THEN** the monitoring module SHALL be imported via `importModule ./monitoring {}`

### Requirement: Monitoring enabled by default for all servers

The system SHALL set `server.monitoring.enable` to `true` by default for all servers.

#### Scenario: Default monitoring state

- **WHEN** a server is added to the cluster without explicit monitoring configuration
- **THEN** `server.monitoring.enable` SHALL be `true`

#### Scenario: Monitoring can be explicitly disabled

- **WHEN** a server sets `server.monitoring.enable = false`
- **THEN** no monitoring exporters or agents SHALL be deployed on that server

### Requirement: Exporter auto-detection based on existing module state

The system SHALL auto-enable application exporters based on existing server module state, without requiring explicit exporter configuration.

#### Scenario: Caddy exporter follows proxy state

- **WHEN** a server has `server.proxy.virtualHosts` configured
- **THEN** `server.monitoring.exporters.caddy.enable` SHALL default to `true`

#### Scenario: PostgreSQL exporter follows database state

- **WHEN** PostgreSQL databases are configured on the IO primary host
- **THEN** `server.monitoring.exporters.postgres.enable` SHALL default to `true` on that host

#### Scenario: Redis exporter follows database state

- **WHEN** Redis instances are configured on the IO primary host
- **THEN** `server.monitoring.exporters.redis.enable` SHALL default to `true` on that host

### Requirement: All configurations guarded by mkIf

All monitoring-related NixOS configuration SHALL be wrapped in `lib.mkIf` guards using the appropriate enable options. No monitoring services SHALL be deployed when the feature is disabled.

#### Scenario: Disabled monitoring produces no services

- **WHEN** `server.monitoring.enable` is `false`
- **THEN** no monitoring-related systemd services, packages, or firewall rules SHALL be present in the system configuration

#### Scenario: Collector disabled on non-primary hosts

- **WHEN** a server is NOT the monitoring primary host
- **THEN** Prometheus, Loki, Grafana, and Alertmanager SHALL NOT be deployed on that server

### Requirement: Secrets managed via sops-nix

All sensitive configuration (OAuth2 secrets, API tokens, webhook URLs) SHALL be stored in sops-encrypted secret files and referenced via `config.sops.secrets`.

#### Scenario: Secrets not in Nix store

- **WHEN** monitoring services are configured
- **THEN** no secret values SHALL appear in the Nix store or in generated configuration files readable by other users

#### Scenario: Secrets available at runtime

- **WHEN** a monitoring service starts
- **THEN** it SHALL have access to its required secrets via sops secret file paths

### Requirement: Documentation updated with module changes

Documentation in `docs/` SHALL be created or updated to reflect the monitoring module's options, architecture, and usage.

#### Scenario: Module documentation exists

- **WHEN** the monitoring module is complete
- **THEN** `docs/modules/nixos/server/monitoring.md` SHALL exist with option descriptions, architecture overview, and configuration examples
