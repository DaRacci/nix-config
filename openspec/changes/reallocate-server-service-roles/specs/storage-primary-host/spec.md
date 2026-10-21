# storage-primary-host Specification

## Purpose

Define how the system provides a `server.storagePrimaryHost` option that determines which host runs primary storage services (MinIO cluster master, SeaweedFS evaluation deployment, shared object storage), replacing the previous coupling to `server.ioPrimaryHost`.

## ADDED Requirements

### Requirement: Storage primary host option on server module

The system SHALL provide a `server.storagePrimaryHost` option in `modules/nixos/server/default.nix` that accepts a hostname string and defaults to the value mapped from `allocations.server.storagePrimaryHost`.

#### Scenario: Option is readable on every host

- **WHEN** any server host evaluates its configuration
- **THEN** `config.server.storagePrimaryHost` SHALL contain the hostname string assigned by the flake allocation

### Requirement: Primary storage services gated to storage primary host

The system SHALL gate MinIO and SeaweedFS evaluation services such that they run only on the host matching `server.storagePrimaryHost`.

#### Scenario: Storage primary host runs MinIO

- **WHEN** `networking.hostName` matches `config.server.storagePrimaryHost`
- **THEN** that host SHALL enable MinIO with the cluster MinIO configuration

#### Scenario: Storage primary host runs SeaweedFS evaluation

- **WHEN** `networking.hostName` matches `config.server.storagePrimaryHost`
- **THEN** that host SHALL enable the SeaweedFS evaluation deployment (master, volume, filer, S3 gateway)

#### Scenario: Non-primary host does not run storage services

- **WHEN** `networking.hostName` does not match `config.server.storagePrimaryHost`
- **THEN** that host SHALL NOT enable MinIO or SeaweedFS evaluation service instances

### Requirement: Storage mount helpers resolve to storage primary host

The system SHALL update all storage mount helpers (`swfsMount`, bucket management, backend service endpoint resolution) to reference `server.storagePrimaryHost` instead of `server.ioPrimaryHost`.

#### Scenario: SeaweedFS mount helper uses storage primary host

- **WHEN** `swfsMount` evaluates the SeaweedFS master endpoint
- **THEN** it SHALL use `config.server.storagePrimaryHost` as the master address, not `config.server.ioPrimaryHost`

#### Scenario: Bucket management helper uses storage primary host

- **WHEN** the bucket management module resolves MinIO endpoint addresses
- **THEN** it SHALL use `config.server.storagePrimaryHost` as the MinIO server address, not `config.server.ioPrimaryHost`

### Requirement: Storage module gating uses storage primary host

The system SHALL update the storage module import logic in `modules/nixos/server/storage/seaweedfs.nix` and `modules/nixos/server/storage/bucket.nix` to gate on `server.storagePrimaryHost`.

#### Scenario: SeaweedFS evaluation gate changed

- **WHEN** `seaweedfs.nix` evaluates whether to enable evaluation services
- **THEN** it SHALL compare `server.storagePrimaryHost` against the local hostname, not `server.ioPrimaryHost`

#### Scenario: MinIO placement gate changed

- **WHEN** `bucket.nix` evaluates where to place MinIO
- **THEN** it SHALL compare `server.storagePrimaryHost` against the local hostname, not `server.ioPrimaryHost`
