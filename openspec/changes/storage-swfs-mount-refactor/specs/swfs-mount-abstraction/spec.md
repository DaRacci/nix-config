## ADDED Requirements

### Requirement: Storage mounts use the renamed swfsMount interface

The system SHALL expose declarative storage mounts through `server.storage.swfsMount` and SHALL remove the repository-local `server.storage.bucketMounts` interface.

#### Scenario: Maintainer declares a named storage mount

- **WHEN** a maintainer defines `server.storage.swfsMount.<name>` in a NixOS configuration
- **THEN** the system SHALL evaluate that entry as a named storage mount definition

#### Scenario: Legacy option is not supported

- **WHEN** a maintainer continues using `server.storage.bucketMounts`
- **THEN** the configuration SHALL no longer receive a repository-local bucket-mount option from the storage module

### Requirement: Every mount definition declares common metadata and a backend

Each `server.storage.swfsMount.<name>` entry SHALL include a backend selector and SHALL support shared mount metadata for mount location, ownership, permissions, and health-check behavior.

#### Scenario: Common mount metadata is applied

- **WHEN** a mount entry specifies `mountLocation`, `uid`, `gid`, or `umask`
- **THEN** the generated mount behavior SHALL apply those settings regardless of whether the backend is MinIO or SeaweedFS

#### Scenario: Backend choice is explicit

- **WHEN** a mount entry is evaluated
- **THEN** the entry SHALL resolve exactly one backend-specific configuration path based on its declared backend selector
