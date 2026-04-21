## ADDED Requirements

### Requirement: VM tests generate runtime dummy secrets

The system SHALL generate runtime test secret files under `/run/secrets` or an equivalent runtime path so sops-dependent modules can evaluate and start without real secrets.

#### Scenario: Test node starts without real sops keys
- **WHEN** a VM test node evaluates and boots in CI
- **THEN** secret-dependent modules SHALL find the expected runtime secret paths
- **AND** the test SHALL NOT require production sops keys

#### Scenario: No real secrets committed or injected
- **WHEN** the test secret generation mechanism is configured
- **THEN** the repository SHALL NOT gain real secret material for VM testing

### Requirement: Generated secrets preserve sops path semantics

The system SHALL present generated test secrets through the same path-based access pattern expected by modules that use `config.sops.secrets.*.path`.

#### Scenario: Secret consumer reads generated path
- **WHEN** a service in the VM test reads a configured sops secret path
- **THEN** that path SHALL resolve to a generated runtime file with suitable dummy content
