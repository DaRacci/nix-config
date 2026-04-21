## ADDED Requirements

### Requirement: CI exposes per-server VM integration test checks

The system SHALL expose `vm-test-<host>` check attributes for every server host from the CI flake partition using `pkgs.testers.runNixOSTest`.

#### Scenario: All server hosts appear in checks output
- **WHEN** the CI checks output is evaluated
- **THEN** it SHALL include a `vm-test-<host>` attribute for each server host discovered from repository host structure

#### Scenario: VM tests stay out of default flake check flow
- **WHEN** maintainers run default `nix flake check`
- **THEN** the VM integration tests SHALL NOT be implicitly added to that default path

### Requirement: VM harness is derived from server host discovery

The system SHALL build the VM test list from repository host discovery or equivalent flake allocation data rather than hardcoded hostnames in the harness implementation.

#### Scenario: New server host receives a check
- **WHEN** a new server host is added through the repository host structure
- **THEN** the VM test harness SHALL be able to expose a matching `vm-test-<host>` check without rewriting a static hostname list
