## Purpose

Define how the SeaweedFS evaluation deployment is gated to the IO primary host and what components it includes.

## Requirements

### Requirement: SeaweedFS evaluation services run only on the IO primary host

The system SHALL enable SeaweedFS evaluation services only on the host selected by `server.ioPrimaryHost`.

#### Scenario: IO primary host enables SeaweedFS

- **WHEN** a host's `networking.hostName` matches `config.server.ioPrimaryHost`
- **THEN** that host SHALL enable the SeaweedFS evaluation services

#### Scenario: Non-IO-primary host does not enable SeaweedFS

- **WHEN** a host's `networking.hostName` does not match `config.server.ioPrimaryHost`
- **THEN** that host SHALL NOT enable the SeaweedFS evaluation services

### Requirement: Evaluation deployment uses all-in-one SeaweedFS components

The system SHALL run the SeaweedFS master, volume, filer, and S3-compatible gateway components as an evaluation deployment on the IO primary host.

#### Scenario: Evaluation host runs all required components

- **WHEN** SeaweedFS evaluation is enabled on the IO primary host
- **THEN** the host SHALL configure the required all-in-one SeaweedFS components needed for S3 evaluation
