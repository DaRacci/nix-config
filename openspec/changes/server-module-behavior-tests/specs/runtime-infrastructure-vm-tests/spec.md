## ADDED Requirements

### Requirement: Distributed builder SSH user is provisioned with authorized key from repository config

The system SHALL, on the build worker host, provision a dedicated SSH builder user with an authorized public key sourced from the repository's `distributed-builds.nix` or equivalent module at `modules/nixos/server/distributed-builds.nix`. The SSH key SHALL be the one declared in the flake's host metadata for the builder host, not a hard-coded default. The test SHALL verify that key-based authentication succeeds from the builder host to the worker host.

#### Scenario: SSH builder user exists and accepts key-based authentication from builder host

- **GIVEN** a two-node VM topology with a builder host (`nixio`) and a build worker host (`nixcloud`)
- **AND** `distributed-builds.nix` declares an SSH key pair for the builder user
- **WHEN** the builder host initiates an SSH connection to the worker host as the builder user using the declared private key
- **THEN** the SSH connection SHALL succeed without password prompt
- **AND** the authenticated user on the worker host SHALL match the expected builder username

#### Scenario: SSH connection with unauthorized key is rejected

- **GIVEN** the same topology
- **WHEN** the builder host attempts SSH with a key NOT in the worker's `authorized_keys`
- **THEN** the SSH connection SHALL be rejected (permission denied)

### Requirement: Nix remote store reachability from builder to worker host

The system SHALL configure the builder host such that `nix store ping` succeeds against the worker host's remote Nix store. This validates the Nix remote builder protocol connectivity — SSH transport, Nix daemon socket forwarding, and store path permissions.

#### Scenario: nix store ping succeeds from builder to worker

- **GIVEN** the same two-node topology with SSH builder access established
- **WHEN** the builder host executes `nix store ping --store ssh://builder@nixcloud`
- **THEN** the command SHALL exit with status 0
- **AND** the output SHALL indicate a successful store ping (e.g., "store ping from" or a version string)

#### Scenario: nix build derivation succeeds on remote builder

- **GIVEN** same topology
- **WHEN** the builder host submits a trivial Nix derivation (e.g., `builtins.derivation { name = "test"; builder = "/bin/sh"; args = [ "-c" "echo ok > $out" ]; system = builtins.currentSystem; }`) for evaluation on the remote store via `nix-build --store ssh://builder@nixcloud`
- **THEN** the derivation SHALL build successfully on the worker host
- **AND** the output path SHALL be accessible on the worker host's store

### Requirement: Custom SSH shell guard restricts commands to authorized set

The system SHALL, if `modules/nixos/server/ssh-shell/` implements a custom SSH shell wrapper, restrict commands executed over SSH by the builder user to an authorized set (e.g., `nix-daemon` commands, store operations, or a specific allowlist). Commands outside the authorized set SHALL be rejected.

#### Scenario: Authorized nix-daemon command passes through custom shell

- **GIVEN** a two-node topology where the worker host runs the custom SSH shell guard
- **WHEN** the builder SSH session executes `nix-daemon --stdio` (or equivalent authorized command)
- **THEN** the command SHALL execute successfully
- **AND** the custom shell SHALL NOT block the command

#### Scenario: Unauthorized command is rejected by custom shell

- **GIVEN** same topology
- **WHEN** the builder SSH session executes a non-whitelisted command (e.g., `cat /etc/shadow`, `rm -rf /`, or a generic shell)
- **THEN** the command SHALL be rejected
- **AND** the SSH session SHALL close or return a specific error message defined by the shell guard
- **AND** the restriction SHALL be enforced by the custom shell, not merely by filesystem permissions

#### Scenario: Custom shell bypass via SSH options is blocked

- **GIVEN** same topology
- **WHEN** an SSH client attempts to bypass the shell guard by passing a command via `-T` or `-N` flags or by requesting a shell without a command
- **THEN** the guard SHALL prevent unauthorized execution
- **AND** if a raw shell is requested, the guard SHALL either reject the session or drop into a restricted environment with no command execution capabilities

### Requirement: Distributed build configuration is gated to designated builder/worker hosts only

The system SHALL enable distributed builder SSH user and remote store configuration only on hosts designated as builders or workers in the flake allocations. Non-designated hosts SHALL NOT have the builder SSH user or remote store build capability configured.

#### Scenario: Non-builder host does not have builder user

- **GIVEN** a host not designated as a builder or worker in the flake allocations
- **WHEN** the test inspects the host's user accounts or SSH configuration
- **THEN** the builder SSH user SHALL NOT exist on that host
- **AND** `nix.store` (or equivalent) SHALL NOT be configured for remote building on that host
