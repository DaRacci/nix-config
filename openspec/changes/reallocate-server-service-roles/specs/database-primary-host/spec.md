# database-primary-host Specification

## Purpose

Define how the system provides a `server.databasePrimaryHost` option that determines which host runs primary database services (PostgreSQL, pgAdmin, Redis), replacing the previous coupling to `server.ioPrimaryHost`.

## ADDED Requirements

### Requirement: Database primary host option on server module

The system SHALL provide a `server.databasePrimaryHost` option in `modules/nixos/server/default.nix` that accepts a hostname string and defaults to the value mapped from `allocations.server.databasePrimaryHost`.

#### Scenario: Option is readable on every host

- **WHEN** any server host evaluates its configuration
- **THEN** `config.server.databasePrimaryHost` SHALL contain the hostname string assigned by the flake allocation

### Requirement: Primary database services gated to database primary host

The system SHALL gate PostgreSQL, pgAdmin, and Redis service instances such that they run only on the host matching `server.databasePrimaryHost`.

#### Scenario: Database primary host runs PostgreSQL

- **WHEN** `networking.hostName` matches `config.server.databasePrimaryHost`
- **THEN** that host SHALL enable the shared PostgreSQL instance with all cluster databases

#### Scenario: Database primary host runs pgAdmin

- **WHEN** `networking.hostName` matches `config.server.databasePrimaryHost`
- **THEN** that host SHALL enable pgAdmin

#### Scenario: Database primary host runs Redis

- **WHEN** `networking.hostName` matches `config.server.databasePrimaryHost`
- **THEN** that host SHALL enable the shared Redis instance

#### Scenario: Non-primary host does not run database services

- **WHEN** `networking.hostName` does not match `config.server.databasePrimaryHost`
- **THEN** that host SHALL NOT enable PostgreSQL, pgAdmin, or Redis service instances

### Requirement: Database connection defaults key off database primary host

The system SHALL update the `server.database.host` default so that it resolves to `"localhost"` on the database primary host and to `config.server.databasePrimaryHost` on all other hosts.

#### Scenario: Localhost on database primary host

- **WHEN** a host's `networking.hostName` matches `config.server.databasePrimaryHost`
- **THEN** `config.server.database.host` SHALL default to `"localhost"`

#### Scenario: Remote hostname on other hosts

- **WHEN** a host's `networking.hostName` does not match `config.server.databasePrimaryHost`
- **THEN** `config.server.database.host` SHALL default to `config.server.databasePrimaryHost`

### Requirement: Database module helpers reference database primary host

The system SHALL update `postgres.nix`, `redis.nix`, and `guardian.nix` helpers to reference `server.databasePrimaryHost` instead of `server.ioPrimaryHost` when deciding where to run primary instances and where to collect remote database registrations.

#### Scenario: PostgreSQL helper uses database primary host for gating

- **WHEN** `postgres.nix` evaluates whether to enable a local PostgreSQL instance
- **THEN** it SHALL compare `server.databasePrimaryHost` against the local hostname, not `server.ioPrimaryHost`

#### Scenario: Redis helper uses database primary host for gating

- **WHEN** `redis.nix` evaluates whether to enable a local Redis instance
- **THEN** it SHALL compare `server.databasePrimaryHost` against the local hostname, not `server.ioPrimaryHost`

#### Scenario: Guardian helper uses database primary host for registration

- **WHEN** `guardian.nix` collects remote database registrations
- **THEN** it SHALL use `server.databasePrimaryHost` as the target for primary database connection strings

### Requirement: Application database declarations continue to work

The system SHALL preserve the `server.database.postgres.<name>` interface so that applications declaring PostgreSQL databases work identically regardless of which host runs the PostgreSQL instance.

#### Scenario: Application declares database without host changes

- **WHEN** an application sets `server.database.postgres.<name>.enable = true`
- **THEN** the database SHALL be created on the host running PostgreSQL, irrespective of which host that is
- **AND** the application's connection string SHALL resolve through `server.database.host`
