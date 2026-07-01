## ADDED Requirements

### Requirement: VM integration test documentation explains full architecture and usage

The system SHALL document the VM integration testing framework at `docs/src/development/vm_integration_tests.md`, covering the `nixosTestConfigurations` flake attribute, two test modes (auto-discovered and explicit), the VM test profile override policy with disabled-service rationale, proxmoxLXC overrides, deterministic sops secret derivation, scenario authoring guidance, local execution commands, CI behavior in the separate `.woodpecker/test-vm.yaml` workflow, and the relationship to the existing `checks.cluster` integration test.

#### Scenario: Documentation linked from SUMMARY.md
- **WHEN** the VM integration test documentation is added at `docs/src/development/vm_integration_tests.md`
- **THEN** it SHALL be linked from `docs/src/SUMMARY.md` under the Development section

#### Scenario: Documentation explains `nixosTestConfigurations` and its relationship to `nixosConfigurations`
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL explain that VM test derivations live under the `nixosTestConfigurations` flake attribute (mirroring the `nixosConfigurations` naming convention), outside the `checks` attribute so `nix flake check` does not invoke them implicitly
- **AND** it SHALL describe how each `nixosTestConfigurations.<host>` entry wraps the corresponding `nixosConfigurations.<host>` with test-only overrides

#### Scenario: Documentation describes two test authoring modes
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL describe the auto-discovered mode — a `nixosTestConfigurations.<host>` entry generated automatically for any host that declares `server.tests.units`
- **AND** it SHALL describe the explicit scenario mode — standalone test files under `tests/` that define arbitrary multi-machine topologies with custom configuration, not tied to a single production host

#### Scenario: Documentation covers the disabled-services policy with concrete examples
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL document the policy that services requiring real external API keys or OAuth credentials are explicitly disabled in test VMs
- **AND** it SHALL provide concrete disabled-service examples (e.g., Tailscale needs a real auth key; MCPO with GitHub or AniList tokens; any service configured with OAuth secrets that would attempt outbound connections to real providers)
- **AND** it SHALL explain the rationale: these services cannot meaningfully validate in an isolated VM without real credentials, and disabling them avoids spurious failures while preserving config structure

#### Scenario: Documentation covers proxmoxLXC override rationale
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL document that the VM test profile overrides `proxmoxLXC.manageNetwork` and `proxmoxLXC.manageHostName` to `false`
- **AND** it SHALL explain that QEMU test driver networking manages these concerns instead, so the proxmoxLXC flags must be disabled to avoid conflicts

#### Scenario: Documentation covers deterministic sops secret generation
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL explain that test VMs derive secret values deterministically from the secret key path (e.g., `secrets.db-password` → value `"db-password"`)
- **AND** it SHALL explain why this matters for cross-host consistency — shared secrets (DB passwords, API keys shared between hosts) resolve to the same predictable value without real sops keys

#### Scenario: Documentation includes a scenario authoring walkthrough
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL include a step-by-step walkthrough for writing a new scenario, covering:
  - Creating an auto-discovered test by adding `server.tests.units` entries to a host configuration
  - Creating an explicit multi-machine test file under `tests/`
  - Using the VM test profile (`tests/profiles/vm-test.nix`) in test node definitions
  - Adding service-specific assertions

#### Scenario: Documentation shows local execution commands
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL show the local command to build a single host VM test: `nix build .#nixosTestConfigurations.<host>`
- **AND** it SHALL note the KVM requirement: the command requires `/dev/kvm` access and will be slow without acceleration

#### Scenario: Documentation describes CI gating and KVM runner requirements
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL explain that VM tests execute as a separate `.woodpecker/test-vm.yaml` workflow on PR events only, not on push or tag events
- **AND** it SHALL document that for the initial implementation ALL server host VM tests run on every PR event; affected-host selection (building only hosts changed by a PR) is deferred to a future iteration
- **AND** it SHALL document the KVM runner requirement — the Woodpecker runner must expose `/dev/kvm` for QEMU acceleration, or tests will be impractically slow
- **AND** it SHALL note that default `nix flake check` does not include VM tests

#### Scenario: Documentation describes relationship to existing `checks.cluster`
- **WHEN** a maintainer reads the documentation
- **THEN** it SHALL explain that `checks.cluster` (the existing all-7-nodes smoke test) remains unchanged and is complemented by the new per-host and per-service granular tests under `nixosTestConfigurations`
- **AND** it SHALL explain the difference: `checks.cluster` validates fleet-wide boot and basic connectivity in one derivation, while `nixosTestConfigurations` enables targeted per-host or per-service validation
