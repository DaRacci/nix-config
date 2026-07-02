# seaweedfs-io-primary-deployment Specification

## Purpose

Define how the SeaweedFS evaluation deployment is gated to the storage primary host and what components it includes. This spec replaces the previous gating mechanism that used `server.ioPrimaryHost` with `server.storagePrimaryHost`.

## RENAMED Requirements

### Requirement: SeaweedFS evaluation services run only on the storage primary host

[Renamed from: "SeaweedFS evaluation services run only on the IO primary host"]

The system SHALL enable SeaweedFS evaluation services only on the host selected by `server.storagePrimaryHost`.

#### Scenario: Storage primary host enables SeaweedFS

- **WHEN** a host's `networking.hostName` matches `config.server.storagePrimaryHost`
- **THEN** that host SHALL enable the SeaweedFS evaluation services

#### Scenario: Non-storage-primary host does not enable SeaweedFS

- **WHEN** a host's `networking.hostName` does not match `config.server.storagePrimaryHost`
- **THEN** that host SHALL NOT enable the SeaweedFS evaluation services

## MODIFIED Requirements

### Requirement: Evaluation deployment uses all-in-one SeaweedFS components

The system SHALL run the SeaweedFS master, volume, filer, and S3-compatible gateway components as an evaluation deployment on the storage primary host.

#### Scenario: Evaluation host runs all required components

- **WHEN** SeaweedFS evaluation is enabled on the storage primary host
- **THEN** the host SHALL configure the required all-in-one SeaweedFS components needed for S3 evaluation
