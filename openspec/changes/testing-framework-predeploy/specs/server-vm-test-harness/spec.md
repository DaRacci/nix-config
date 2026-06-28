## ADDED Requirements

### Requirement: Flake exposes `nixosTestConfigurations` as a top-level attribute

The system SHALL expose a top-level flake attribute `nixosTestConfigurations` containing VM integration test derivations built with `pkgs.testers.runNixOSTest`. This attribute SHALL live at the same level as `nixosConfigurations`, `packages`, and other top-level flake outputs — it SHALL NOT be nested under `checks`.

The `nixosTestConfigurations` attribute SHALL be defined in the `nixos` partition alongside `nixosConfigurations`, reusing the same host discovery infrastructure.

#### Scenario: `nixosTestConfigurations` is top-level in flake output
- **WHEN** the flake output schema is evaluated
- **THEN** `nixosTestConfigurations` SHALL appear at the top level, directly under `flake` alongside `nixosConfigurations`, `packages`, etc.
- **AND** `nixosTestConfigurations` SHALL NOT appear under any `checks` subtree

#### Scenario: Attribute defined in nixos partition
- **WHEN** the `nixos` flake partition module is evaluated
- **THEN** it SHALL produce the `nixosTestConfigurations` attribute
- **AND** it SHALL reuse `getHostsByType` from the existing host discovery infrastructure

### Requirement: Per-host entries from auto-discovered server hosts

The system SHALL generate a `nixosTestConfigurations.<host>` entry for every server host discovered through repository host structure via `getHostsByType`, deriving the hostname list automatically rather than from a hardcoded static list.

#### Scenario: All server hosts appear as `nixosTestConfigurations` entries
- **WHEN** `nixosTestConfigurations` is evaluated
- **THEN** it SHALL contain a `<host>` attribute for each server host returned by `(getHostsByType self).server`
- **AND** each `<host>` entry SHALL be a derivation compatible with `nix build`

#### Scenario: New server host auto-appears in `nixosTestConfigurations`
- **WHEN** a new server host directory is added under `hosts/server/`
- **THEN** the new host SHALL automatically appear in `nixosTestConfigurations` without modifying the harness implementation

### Requirement: Explicit scenario files

The system SHALL support explicit scenario files in `tests/` that produce `nixosTestConfigurations.<scenario-name>` entries. The builder at `tests/builder.nix` SHALL aggregate these scenario files alongside auto-discovered host entries to assemble the complete `nixosTestConfigurations` attribute. These scenario files define arbitrary test topologies with custom NixOS configurations, independent of a single production host.

#### Scenario: Scenario files produce named entries
- **WHEN** a file `tests/<scenario-name>.nix` matches the explicit scenario convention
- **THEN** the system SHALL produce a `nixosTestConfigurations.<scenario-name>` entry
- **AND** that entry SHALL use the scenario file's definition rather than auto-discovery from host config

#### Scenario: Scenario entries coexist with host-derived entries
- **WHEN** both host-derived and scenario-derived entries are present
- **THEN** both sets of entries SHALL coexist in `nixosTestConfigurations` without conflict

### Requirement: Existing `checks.cluster` continues unchanged

The existing cluster integration test (`checks.cluster` from `tests/default.nix`) SHALL continue to function identically. The `tests/default.nix` file itself SHALL remain completely unmodified. This requirement is additive — `nixosTestConfigurations` complements rather than replaces the cluster test.

#### Scenario: `checks.cluster` remains accessible and unmodified
- **GIVEN** the existing CI partition module producing `checks.cluster`
- **WHEN** `nix build .#checks.x86_64-linux.cluster` is invoked
- **THEN** the cluster test SHALL build and run as before, booting all server hosts with the unmodified `tests/default.nix` logic
- **AND** the cluster test source (`tests/default.nix`) SHALL NOT be modified in any way by the addition of `nixosTestConfigurations`
- **AND** the new VM test builder infrastructure SHALL live in `tests/builder.nix`, leaving `tests/default.nix` completely untouched

#### Scenario: `nixosTestConfigurations` does not duplicate `checks.cluster`
- **WHEN** `nixosTestConfigurations` is evaluated
- **THEN** it SHALL NOT contain an entry named `cluster` that duplicates the behavior of `checks.cluster`

### Requirement: `nixosTestConfigurations` is excluded from default flake check

The system SHALL ensure that `nixosTestConfigurations` entries are NOT implicitly added to the `checks` evaluation path triggered by `nix flake check`.

#### Scenario: `nix flake check` does not evaluate VM tests
- **WHEN** maintainers run `nix flake check`
- **THEN** the evaluation SHALL NOT include `nixosTestConfigurations` entries in its check graph
- **AND** `nix flake check` SHALL pass or fail independently of the VM test derivations

#### Scenario: VM tests are explicitly invocable
- **GIVEN** `nixosTestConfigurations` is excluded from default check evaluation
- **WHEN** a user runs `nix build .#nixosTestConfigurations.<host>`
- **THEN** the derivation SHALL build and execute the VM test
