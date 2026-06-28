## ADDED Requirements

### Requirement: VM test CI workflow as separate Woodpecker pipeline

The system SHALL provide a dedicated Woodpecker workflow `.woodpecker/test-vm.yaml` that builds and runs VM integration tests from `nixosTestConfigurations.*` on KVM-capable runners. This workflow SHALL be independent of the existing `.woodpecker/check.yaml` workflow.

#### Scenario: Separate workflow file exists

- **WHEN** the Woodpecker CI configuration is inspected
- **THEN** a file `.woodpecker/test-vm.yaml` SHALL exist
- **AND** it SHALL be a separate workflow from `.woodpecker/check.yaml`
- **AND** `.woodpecker/check.yaml` SHALL remain unmodified by this addition

#### Scenario: Workflow builds nixosTestConfigurations targets

- **WHEN** the `.woodpecker/test-vm.yaml` workflow is defined
- **THEN** the workflow SHALL include build steps that evaluate `nixosTestConfigurations.*` targets
- **AND** SHALL use `nix-fast-build` or direct `nix build` commands to build per-host VM test derivations
- **AND** SHALL NOT reference `checks.<system>.vm-test-<host>` or any `checks` subtree path

#### Scenario: Workflow does not modify run-woodpecker-ci script

- **WHEN** the `.woodpecker/test-vm.yaml` workflow is added
- **THEN** the existing `run-woodpecker-ci` script SHALL NOT be modified or depended upon

### Requirement: KVM runner requirement

The workflow SHALL target Woodpecker runners that expose hardware virtualization support, ensuring NixOS VM tests can boot QEMU guests.

#### Scenario: Workflow labels select KVM runner

- **WHEN** the `.woodpecker/test-vm.yaml` workflow defines runner labels
- **THEN** the workflow SHALL include a label such as `kvm: true` or an equivalent runner selector that ensures the job runs only on a KVM-capable agent
- **AND** the selected runner SHALL expose `/dev/kvm` to the build container

### Requirement: PR-only workflow gating

The VM test workflow SHALL execute only on pull request events. Non-pull-request events SHALL skip the workflow entirely.

#### Scenario: Pull request event triggers VM test workflow

- **WHEN** Woodpecker processes a `pull_request` event
- **THEN** the `.woodpecker/test-vm.yaml` workflow SHALL be triggered
- **AND** SHALL execute the configured VM test build steps on a KVM-capable runner

#### Scenario: Non-pull-request events skip VM test workflow

- **WHEN** Woodpecker processes a non-pull-request event (`push`, `manual`, `tag`, etc.)
- **THEN** the `.woodpecker/test-vm.yaml` workflow SHALL NOT run
- **AND** SHALL produce no VM test jobs for that event

### Requirement: Per-host pass/fail reporting

The workflow SHALL report per-host pass/fail status for each VM test derivation it builds, enabling maintainers to identify failing hosts independently.

#### Scenario: Per-host build status is surfaced

- **WHEN** the `.woodpecker/test-vm.yaml` workflow runs for a set of server hosts
- **THEN** each host's VM test build SHALL produce an independent pass or fail status
- **AND** the workflow output SHALL make it possible to determine which host(s) passed and which failed

#### Scenario: Existing check.yaml is unaffected by VM test results

- **WHEN** the `.woodpecker/test-vm.yaml` workflow reports any failure
- **THEN** the `.woodpecker/check.yaml` workflow status SHALL NOT be affected
- **AND** a failure in `.woodpecker/test-vm.yaml` SHALL NOT block or alter `.woodpecker/check.yaml` execution or reporting

### Requirement: All-server-host execution for initial implementation

For the initial implementation, the workflow SHALL build `nixosTestConfigurations.<host>` for ALL server hosts on every pull request event. Affected-host selection (building only hosts changed by a PR) is deferred to a future iteration.

#### Scenario: Every PR builds all server host VM tests

- **WHEN** the `.woodpecker/test-vm.yaml` workflow triggers on a pull request event
- **THEN** the workflow SHALL build `nixosTestConfigurations.<host>` for every server host defined in the flake
- **AND** SHALL NOT filter or select hosts based on which files changed in the PR
- **AND** the specification SHALL note that affected-host selection is deferred and is not part of the initial implementation

#### Scenario: Deferred affected-host selection is documented

- **WHEN** a maintainer reviews the workflow specification
- **THEN** it SHALL be explicitly documented that running VM tests only for affected hosts is a future feature
- **AND** the initial implementation intentionally runs all hosts on every PR to establish baseline reliability before introducing selective execution
