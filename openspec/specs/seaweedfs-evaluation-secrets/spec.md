## Purpose

Define the separate sops-managed security material used by the SeaweedFS evaluation deployment.

## Requirements

### Requirement: SeaweedFS evaluation uses separate sops-managed security material

The system SHALL store SeaweedFS evaluation security material in separate sops-managed secrets rather than reusing or overwriting MinIO secret entries in place.

#### Scenario: SeaweedFS secret entries added separately

- **WHEN** SeaweedFS evaluation secrets are added
- **THEN** they SHALL be stored under distinct secret entries for SeaweedFS evaluation

#### Scenario: Existing MinIO secrets preserved

- **WHEN** SeaweedFS evaluation secrets are configured
- **THEN** existing MinIO secret entries SHALL remain intact

### Requirement: SeaweedFS evaluation secrets cover mTLS and inter-component authentication

The system SHALL provide the TLS certificates, private keys, and JWT secrets needed for Caddy-to-component mTLS and SeaweedFS inter-component authentication through separate sops-managed entries.

#### Scenario: Proxy and component authentication material available

- **WHEN** the SeaweedFS evaluation service starts
- **THEN** the deployment SHALL reference the sops-provided TLS and JWT material required for the evaluation proxy and service communication paths
