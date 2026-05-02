## ADDED Requirements

### Requirement: MinIO mounts continue to use s3fs
The system SHALL implement MinIO-backed `server.storage.swfsMount` entries through s3fs-based FUSE mounts.

#### Scenario: MinIO backend creates an s3fs mount
- **WHEN** a mount entry declares `backend = "minio"`
- **THEN** the system SHALL generate an s3fs-backed mount for the configured bucket and mount location

#### Scenario: MinIO backend uses MinIO credentials and endpoint settings
- **WHEN** a MinIO-backed mount is evaluated
- **THEN** the system SHALL use MinIO-specific credentials and endpoint configuration rather than SeaweedFS filer settings

### Requirement: SeaweedFS mounts use weed mount against a filer path
The system SHALL implement SeaweedFS-backed `server.storage.swfsMount` entries through `weed mount` using a filer address and filer path.

#### Scenario: SeaweedFS backend creates a weed mount service
- **WHEN** a mount entry declares `backend = "seaweedfs"`
- **THEN** the system SHALL generate a systemd-managed `weed mount` invocation for the configured mount location

#### Scenario: SeaweedFS backend does not use the S3 gateway mount path
- **WHEN** a SeaweedFS-backed mount is evaluated
- **THEN** the system SHALL mount the configured filer path with `weed mount` instead of mounting the SeaweedFS S3-compatible endpoint through s3fs

### Requirement: Backend-specific settings are validated separately
The system SHALL require only the backend-specific settings relevant to the selected backend and SHALL not require MinIO-specific and SeaweedFS-specific runtime inputs at the same time.

#### Scenario: MinIO entry omits SeaweedFS-only fields
- **WHEN** a MinIO-backed mount is configured without filer-specific options
- **THEN** the configuration SHALL remain valid without requiring SeaweedFS runtime settings

#### Scenario: SeaweedFS entry omits MinIO-only fields
- **WHEN** a SeaweedFS-backed mount is configured without s3fs credentials or bucket endpoint options
- **THEN** the configuration SHALL remain valid without requiring MinIO runtime settings
