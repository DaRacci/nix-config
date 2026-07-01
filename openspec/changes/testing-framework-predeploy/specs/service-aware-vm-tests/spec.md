## ADDED Requirements

### Requirement: Every test includes baseline VM assertions

The system SHALL apply a baseline VM test to every server host that verifies boot success, multi-user readiness, SSH availability, firewall state, journald persistence, and absence of unexpected failed units.

#### Scenario: Baseline assertions run for any server host
- **WHEN** a server host VM test is executed
- **THEN** the test SHALL verify the baseline system assertions for that host

### Requirement: Services can auto-discover unit tests from `server.tests.units`

The system SHALL harvest test functions declared in `server.tests.units` for each host and run them inside individual Python `subtest` blocks. This allows any module to declaratively attach service-specific checks without modifying the test runner.

#### Scenario: Auto-discovered unit tests run inside subtests
- **WHEN** a host configuration defines entries in `server.tests.units`
- **THEN** the VM test SHALL iterate those entries and execute each `testScript` inside a named `subtest`
- **AND** the `subtest` name SHALL match the unit's `name` attribute
- **AND** test failure SHALL report the host name and the unit name

#### Scenario: Disabled-service tests are silently skipped
- **WHEN** a service is disabled by the VM test profile (per the disabled-services policy defined in the vm-test-profile-overrides spec)
- **THEN** its `server.tests.units` entry SHALL be excluded from auto-discovery
- **AND** the skip SHALL be silent — no warning, no placeholder entry
- **AND** the rationale is: services that are disabled cannot run, so their tests cannot pass

### Requirement: Cross-service and multi-node scenarios are authored under `tests/scenarios/`

The system SHALL support explicit scenario files under `tests/scenarios/` for testing interactions between services or multi-node behaviors that cannot be exercised by unit tests alone.

#### Scenario: Scenario file produces a runnable test
- **WHEN** a file `tests/scenarios/<name>/test.nix` exists
- **THEN** it SHALL produce a `nixosTestConfigurations.<name>` entry
- **AND** the file SHALL define a complete NixOS test with `nodes` and `testScript`
- **AND** the baseline assertions SHALL be called for every node before scenario-specific checks run

#### Scenario: Scenario tests can define multi-node configurations
- **WHEN** a scenario defines multiple nodes in its `nodes` attribute
- **THEN** each node SHALL evaluate as a full NixOS configuration (including the VM test profile module)
- **AND** the test SHALL start all nodes before executing the scenario `testScript`

#### Scenario: Cross-service scenario failure reports context
- **WHEN** a scenario test assertion fails
- **THEN** the failure output SHALL include the scenario name and the node name where the check ran
- **AND** the failure SHALL NOT prevent baseline assertions from completing on other nodes

### Requirement: Tests for single-service behavior use `server.tests.units`, not scenarios

Scenarios are reserved for cross-service or multi-node interactions. Single-service validation belongs in `server.tests.units` alongside the service module that defines it.

#### Scenario: Unit test preferred over scenario for isolated service check
- **WHEN** a service's behavior can be verified inside a single VM with no external dependencies
- **THEN** its test SHALL be declared via `server.tests.units` in the service module
- **AND** SHALL NOT create a scenario file unless cross-service interaction is required

### Requirement: VM test profile module handles all disabled-service policy

The `tests/profiles/vm-test.nix` module is the single source of truth for which services are disabled in test VMs. Neither auto-discovered tests nor scenarios override this policy.

#### Scenario: Disabled-service policy applies uniformly
- **WHEN** any VM test node evaluates (auto-discovered or scenario)
- **THEN** the VM test profile module SHALL be applied
- **AND** its disabled-service decisions SHALL take effect before auto-discovery or scenario evaluation
- **AND** no test mechanism SHALL re-enable a service that the profile has disabled
