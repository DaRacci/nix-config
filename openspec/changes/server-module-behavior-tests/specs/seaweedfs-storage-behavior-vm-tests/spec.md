## ADDED Requirements

### Requirement: S3 bucket creation is visible across all SeaweedFS surfaces in the evaluation deployment

The system SHALL, when a bucket is created via the S3 API on the IO primary host, make the bucket visible in all three SeaweedFS data surfaces: the S3 API listing, the filer directory listing, and the volume server assignment. Existing `seaweedfs-storage-module` and `seaweedfs-io-primary-deployment` specs cover module structure and deployment gating; this requirement covers end-to-end storage behavior verification.

#### Scenario: Bucket created via S3 API appears in filer and volume server

- **GIVEN** a running SeaweedFS evaluation deployment on the IO primary host with master, volume, filer, and S3 gateway components
- **WHEN** a bucket `test-bucket-vm` is created using the AWS S3 SDK or `s3cmd` against the local S3 gateway endpoint
- **THEN** `s3cmd ls` (against S3 gateway) SHALL list `test-bucket-vm`
- **AND** `curl http://localhost:8888/buckets/` (filer API) SHALL list `test-bucket-vm`
- **AND** `curl "http://localhost:9333/dir/assign"` (master/volume assignment) SHALL show a volume server assigned to the bucket's data
- **AND** the test SHALL assert bucket existence via all three surfaces, not only the S3 API

#### Scenario: Object written via S3 is retrievable through filer

- **GIVEN** bucket `test-bucket-vm` exists on the SeaweedFS deployment
- **WHEN** a file with known content (`test-object.txt` containing a deterministic checksum) is uploaded via S3 PUT
- **THEN** `curl http://localhost:8888/buckets/test-bucket-vm/test-object.txt` SHALL return the identical content
- **AND** the filer metadata endpoint SHALL report the object's size and ETag matching the uploaded file

### Requirement: FUSE mount provides read/write I/O roundtrip against SeaweedFS filer

The system SHALL, when SeaweedFS FUSE mount is configured on the IO primary host or a dedicated storage client host, support write-to-mount and read-back operations with content integrity verification. If FUSE mount is gated behind a separate option or hardware requirement, this requirement SHALL apply only when the FUSE mount is enabled.

#### Scenario: Write file to FUSE mount and read back with checksum match

- **GIVEN** SeaweedFS FUSE is mounted at a known path (e.g., `/mnt/seaweedfs`) on the host
- **WHEN** a test writes a 4 KiB file with deterministic content to the mount (`dd if=/dev/zero bs=1024 count=4 | sha256sum > /mnt/seaweedfs/test-file.bin`)
- **AND** reads it back via the FUSE mount path
- **THEN** the read-back content SHALL be identical to the written content, verified by `sha256sum`
- **AND** the filer API SHALL report the file's existence and size matching the written data

#### Scenario: FUSE mount survives volume server restart

- **GIVEN** a file exists on the FUSE mount
- **WHEN** the volume server (`seaweedfs-volume`) is restarted
- **THEN** the FUSE mount SHALL remain accessible (not stale)
- **AND** the pre-existing file SHALL be readable from the mount after the restart

### Requirement: Master leader election is observable and non-disruptive to existing data

The system SHALL, when the SeaweedFS master service restarts, maintain data accessibility and leader election completing within a bounded window. The test SHALL verify that existing bucket and object data remain accessible after master re-election.

#### Scenario: Master restart preserves bucket and object accessibility

- **GIVEN** a bucket with at least one object exists on the SeaweedFS deployment
- **WHEN** `systemctl restart seaweedfs-master` is executed
- **THEN** the master SHALL re-elect a leader (or confirm the same instance)
- **AND** `s3cmd ls` SHALL still list the pre-existing bucket within 10 seconds of master recovery
- **AND** the pre-existing object SHALL be retrievable through the S3 API

### Requirement: Repository-owned storage path proves end-to-end I/O through SeaweedFS layers

The test SHALL exercise a storage path that is owned by the repository configuration — e.g., a bucket, mount point, or filer path declared in `modules/nixos/server/storage/seaweedfs.nix`. This ensures that the module's wiring (S3 gateway config, filer config, volume config, mount options) is correct, not just that upstream SeaweedFS services can start.

#### Scenario: Repository-declared bucket path verified end-to-end

- **GIVEN** the SeaweedFS module declares a repository-managed storage path (e.g., a specific bucket for evaluation data)
- **WHEN** the test writes data to that path
- **THEN** the data SHALL be readable via S3 API, filer API, and (if FUSE mounted) the mount path
- **AND** the test SHALL fail if the module's S3 gateway or filer configuration is misconfigured, even if individual SeaweedFS services report healthy
