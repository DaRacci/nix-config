## ADDED Requirements

### Requirement: Storage documentation explains backend selection and recovery behavior

The system SHALL document how MinIO-backed and SeaweedFS-backed mounts differ, including the use of s3fs for MinIO, `weed mount` for SeaweedFS, and automated mount recovery behavior.

#### Scenario: Backend differences are documented

- **WHEN** a maintainer reads the storage docs for a mount entry
- **THEN** the documentation SHALL explain which settings are common and which settings are backend-specific

#### Scenario: Health-check behavior is documented

- **WHEN** a maintainer reads the operational notes for storage mounts
- **THEN** the documentation SHALL explain that mount health checks can detect stale mounts and trigger automated remount behavior
