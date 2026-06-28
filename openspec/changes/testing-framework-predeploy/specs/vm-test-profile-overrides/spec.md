## ADDED Requirements

### Requirement: Test VMs apply a formal policy module for service and resource overrides

The system SHALL inject a dedicated policy module (`tests/profiles/vm-test.nix`) as a NixOS module into every VM test node. The module SHALL disable services and adjust configuration that is incompatible with or meaningless inside a QEMU VM environment, without modifying any production host configuration.

#### Scenario: Services requiring real external API keys are disabled in test VMs
- **WHEN** a server host is evaluated as a VM test node
- **AND** its configuration enables any of the following services:
  - Tailscale (`services.tailscale`)
  - MCPO (`services.mcpo`) — especially providers requiring GitHub or AniList tokens
  - Ollama (`services.ollama`)
- **THEN** the VM test profile SHALL disable those services for the test node
- **AND** SHALL identify each service by its NixOS option name, not by any third-party secret or OAuth detection mechanism
- **AND** SHALL document the specific disabling reason for each service

#### Scenario: Services are identified by explicit name, not kanidmContexts detection
- **WHEN** the VM test profile selects services to disable
- **THEN** it SHALL use explicit NixOS option name matching (`services.tailscale`, `services.mcpo`, `services.ollama`) to identify targets
- **AND** SHALL NOT inspect `config.server.proxy.kanidmContexts` or any other inferred OAuth secret presence to decide which services to disable
- **AND** SHALL NOT make disablement decisions based on the presence or absence of OAuth secret references in any host configuration

#### Scenario: GPU-dependent services are disabled in test VMs
- **WHEN** a server host is evaluated as a VM test node
- **AND** its configuration enables GPU-dependent services such as:
  - Ollama with ROCm backend (`services.ollama.acceleration = "rocm"`)
  - Any service that depends on GPU device passthrough
- **THEN** the VM test profile SHALL disable those services for the test node
- **AND** SHALL note that QEMU VMs lack GPU passthrough as the reason

#### Scenario: proxmoxLXC networking flags are overridden to false
- **WHEN** a server host is evaluated as a VM test node
- **AND** its configuration includes `proxmoxLXC` settings
- **THEN** the VM test profile SHALL set `proxmoxLXC.manageNetwork = false`
- **AND** SHALL set `proxmoxLXC.manageHostName = false`
- **AND** SHALL document that QEMU test driver networking manages these concerns instead

#### Scenario: Production configurations are not modified
- **WHEN** the VM test profile is applied
- **THEN** no production host file under `hosts/server/` SHALL be altered to remove or adjust service or resource settings for testing purposes
- **AND** the override module SHALL exist solely in `tests/profiles/vm-test.nix`
- **AND** the module SHALL only be imported into test node configurations, never into any production NixOS configuration entry point

### Requirement: Sops secret file content resolves deterministically from key path

The VM test profile SHALL generate deterministic sops secret file content derived from the secret key path, ensuring that the same key path produces the same file content across all test hosts. The profile SHALL use `systemd.tmpfiles.rules` to write the files at boot, avoiding use of a non-existent `sops.secrets.<name>.value` option.

#### Scenario: Same sops key path produces same file content across different hosts
- **WHEN** a VM test node evaluates a sops secret at path `sops.secrets.<name>`
- **AND** another VM test node evaluates a sops secret at the same `<name>`
- **THEN** both nodes SHALL write the identical file content at `config.sops.secrets.<name>.path`

#### Scenario: File content derivation uses key path hash
- **WHEN** the VM test profile generates a test secret
- **THEN** the file content SHALL be derived as `"test-${builtins.hashString "sha256" name}"`
- **AND** the content SHALL be written via `systemd.tmpfiles.rules`: `"f ${config.sops.secrets.<name>.path} 0400 root root - test-${builtins.hashString "sha256" name}"`
- **AND** SHALL NOT require or reference any real sops encryption keys or production secret material

#### Scenario: No real secrets committed or injected
- **WHEN** the VM test profile is active
- **THEN** the repository SHALL NOT gain real secret material for VM testing
- **AND** the deterministic tmpfiles derivation SHALL be the only secret mechanism active under test

#### Scenario: Sops key source assertion is satisfied without real keys
- **WHEN** the VM test profile is active
- **AND** sops-nix enforces a hard assertion requiring at least one key source
- **THEN** the profile SHALL set `sops.age.keyFile = "/dev/null"` to satisfy the assertion without enabling real decryption
- **AND** SHALL set `sops.gnupg.home = null` to disable GnuPG key lookup
- **AND** SHALL set `sops.gnupg.sshKeyPaths = []` to disable SSH-based key lookup
- **AND** SHALL NOT reference `sops.age.sshKeyPaths = []` or `sops.age.keyFile = null`, as those either trigger the assertion or fail to satisfy it

### Requirement: Disabled and overridden items are documented inline

The VM test profile SHALL document every disabled service, every overridden option, and the specific rationale, as inline comments in the module source.

#### Scenario: Each override carries a rationale
- **WHEN** the VM test profile disables a service or overrides an option
- **THEN** the corresponding Nix expression SHALL include a comment explaining why the override applies in a QEMU VM context

#### Scenario: No conflicting `mkForce` on disabled services
- **WHEN** the VM test profile disables a service using `mkForce false`
- **THEN** no other module SHALL use `mkForce` on `services.tailscale.enable`, `services.mcpo.enable`, or `services.ollama.enable`
- **AND** a module that needs to override these services SHALL use lower-priority mechanisms (`lib.mkDefault`) or explicitly coordinate with the VM test profile
- **AND** the profile SHALL document this constraint near each `mkForce false` application
- **NOTE**: `mkForce` collisions cause a hard NixOS module evaluation error; this constraint prevents that failure mode
