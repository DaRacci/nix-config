# cluster-role-allocations Specification

## Purpose

Define how the flake exposes configurable allocation options for database, storage, and auth primary host roles, following the existing `monitoringPrimaryHost` pattern.

## ADDED Requirements

### Requirement: Database primary host allocation option

The system SHALL add a `databasePrimaryHost` option to `allocations.server` in `modules/flake/allocations.nix`, using the same `serverHostnamesEnum` type as `ioPrimaryCoordinator`.

#### Scenario: Allocation option available

- **WHEN** the flake is evaluated
- **THEN** `allocations.server.databasePrimaryHost` SHALL be a configurable option accepting any server hostname

#### Scenario: Allocation mapped to server module

- **WHEN** `allocations.server.databasePrimaryHost` is set
- **THEN** the value SHALL be mapped to `server.databasePrimaryHost` on all server hosts via `modules/flake/apply/system.nix`

### Requirement: Storage primary host allocation option

The system SHALL add a `storagePrimaryHost` option to `allocations.server` in `modules/flake/allocations.nix`, using the same `serverHostnamesEnum` type.

#### Scenario: Allocation option available

- **WHEN** the flake is evaluated
- **THEN** `allocations.server.storagePrimaryHost` SHALL be a configurable option accepting any server hostname

#### Scenario: Allocation mapped to server module

- **WHEN** `allocations.server.storagePrimaryHost` is set
- **THEN** the value SHALL be mapped to `server.storagePrimaryHost` on all server hosts via `modules/flake/apply/system.nix`

### Requirement: Auth primary host allocation option

The system SHALL add an `authPrimaryHost` option to `allocations.server` in `modules/flake/allocations.nix`, using the same `serverHostnamesEnum` type.

#### Scenario: Allocation option available

- **WHEN** the flake is evaluated
- **THEN** `allocations.server.authPrimaryHost` SHALL be a configurable option accepting any server hostname

#### Scenario: Allocation mapped to server module

- **WHEN** `allocations.server.authPrimaryHost` is set
- **THEN** the value SHALL be mapped to `server.authPrimaryHost` on all server hosts via `modules/flake/apply/system.nix`
