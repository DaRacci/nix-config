## ADDED Requirements

### Requirement: VM tests run only in PR-gated Woodpecker CI

The system SHALL run the VM integration test workflow only for pull request events on KVM-capable Woodpecker runners.

#### Scenario: Pull request event runs VM tests
- **WHEN** Woodpecker processes a pull request event
- **THEN** the VM integration test workflow SHALL run the configured VM checks on a runner that exposes `/dev/kvm`

#### Scenario: Non-PR events skip VM tests
- **WHEN** Woodpecker processes a non-pull-request event
- **THEN** the VM integration test workflow SHALL NOT run the PR-gated VM test job

### Requirement: Workflow executes per-host VM check builds

The system SHALL execute VM test derivations by building `checks.<system>.vm-test-<host>` targets or an equivalent per-host matrix selection.

#### Scenario: Host check build command present
- **WHEN** the Woodpecker VM test workflow is defined
- **THEN** the workflow SHALL include commands that build per-host VM test checks
