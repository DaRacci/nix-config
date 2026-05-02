## ADDED Requirements

### Requirement: Evaluation documentation explains scope and constraints

The system SHALL document the SeaweedFS evaluation deployment as a parallel, non-migrating experiment alongside MinIO, including endpoint behavior, proxy expectations, and the purpose of the SeaweedFS security material.

#### Scenario: Documentation follows current repo layout

- **WHEN** SeaweedFS evaluation documentation is added
- **THEN** it SHALL live in the current NixOS server storage documentation hierarchy instead of the legacy component-doc path

#### Scenario: Documentation warns against replacement assumptions

- **WHEN** a maintainer reads the SeaweedFS documentation
- **THEN** it SHALL state that the change is evaluation-only and does not replace or migrate existing MinIO-backed workloads

#### Scenario: Documentation explains security material purpose

- **WHEN** a maintainer reads the SeaweedFS documentation
- **THEN** it SHALL explain that the SeaweedFS sops entries are used for mTLS between Caddy and the SeaweedFS components plus JWT-based inter-component communication
