## ADDED Requirements

### Requirement: VM integration test documentation explains architecture and usage

The system SHALL document the VM integration testing framework, including CI-only scope, VM profile overrides, generated secrets, auto-detection rules, and local execution guidance.

#### Scenario: Documentation linked from summary
- **WHEN** the VM integration test documentation is added
- **THEN** it SHALL be linked from `docs/src/SUMMARY.md`

#### Scenario: Documentation describes CI-only behavior
- **WHEN** a maintainer reads the VM integration test documentation
- **THEN** it SHALL explain that the framework is PR-gated in Woodpecker and not part of the default `nix flake check` path
