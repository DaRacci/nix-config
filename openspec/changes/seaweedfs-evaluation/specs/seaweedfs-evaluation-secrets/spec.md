## ADDED Requirements

### Requirement: SeaweedFS evaluation uses separate sops-managed credential material

The system SHALL store SeaweedFS evaluation credentials or S3 identity configuration in separate sops-managed secrets rather than reusing or overwriting MinIO secret entries in place.

#### Scenario: SeaweedFS secret entries added separately
- **WHEN** SeaweedFS evaluation secrets are added
- **THEN** they SHALL be stored under distinct secret entries for SeaweedFS evaluation

#### Scenario: Existing MinIO secrets preserved
- **WHEN** SeaweedFS evaluation secrets are configured
- **THEN** existing MinIO secret entries SHALL remain intact

### Requirement: SeaweedFS S3 configuration follows upstream filer layout

The system SHALL provide S3 identities or policy data through the upstream `services.seaweedfs.filer.s3.config` path or its equivalent upstream configuration hook.

#### Scenario: Filer S3 config backed by secret file
- **WHEN** the SeaweedFS evaluation service starts
- **THEN** the filer S3 configuration SHALL reference a sops-provided JSON file containing the evaluation identities or policy data
