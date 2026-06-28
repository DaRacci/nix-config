## ADDED Requirements

### Requirement: VM test secrets derived deterministically from key path

The system SHALL generate dummy sops secret values deterministically from the secret key path, so that every `sops.secrets.<name>` declared in a host configuration resolves to a predictable dummy value without requiring real sops encryption keys, production secret material, or any external secret store.

#### Scenario: Secret value derived from key path hash
- **GIVEN** a VM test node that declares `sops.secrets."SOME/SECRET/KEY" = { };`
- **WHEN** the NixOS module system evaluates `sops.secrets."SOME/SECRET/KEY"`
- **THEN** the VM test profile SHALL write the secret file at `config.sops.secrets."SOME/SECRET/KEY".path` using `systemd.tmpfiles.rules`
- **AND** the file content SHALL equal `"test-${builtins.hashString "sha256" "SOME/SECRET/KEY"}"`
- **AND** the derivation SHALL NOT require or reference any real sops encryption keys, age keys, or production secret material
- **AND** the derivation SHALL use only pure Nix built-in functions (`builtins.hashString`) with no file reads or impure operations

#### Scenario: Same key path produces same value across different hosts
- **GIVEN** two distinct VM test nodes (e.g., `nixai` and `nixcloud`)
- **WHEN** both nodes declare `sops.secrets."CLOUDFLARE/DNS_API_TOKEN" = { };`
- **THEN** both nodes SHALL write the identical file content at `config.sops.secrets."CLOUDFLARE/DNS_API_TOKEN".path`
- **AND** the file content SHALL be `"test-${builtins.hashString "sha256" "CLOUDFLARE/DNS_API_TOKEN"}"` regardless of host name, architecture, or any other contextual difference

#### Scenario: Different key paths produce different values
- **GIVEN** a VM test node that declares `sops.secrets."KANIDM/OAUTH2/HASSIO_SECRET" = { };` and `sops.secrets."KANIDM/OAUTH2/NEXTCLOUD_SECRET" = { };`
- **WHEN** both secrets are evaluated
- **THEN** the content at `config.sops.secrets."KANIDM/OAUTH2/HASSIO_SECRET".path` SHALL differ from the content at `config.sops.secrets."KANIDM/OAUTH2/NEXTCLOUD_SECRET".path`
- **AND** each file content SHALL be independently derived from its own key path

### Requirement: Runtime secret paths resolve for sops consumers

The system SHALL present generated test secrets through the same path-based access pattern (`config.sops.secrets.<name>.path`) that modules expect in production, so that services dependent on sops secret paths can evaluate and boot without modification.

#### Scenario: Secret consumer reads generated path
- **GIVEN** a VM test node where a service references `config.sops.secrets."MCP/API_TOKEN".path`
- **WHEN** the NixOS module system evaluates the service configuration
- **THEN** `config.sops.secrets."MCP/API_TOKEN".path` SHALL resolve to a path under the runtime secret directory (e.g., `/run/secrets/MCP/API_TOKEN` or equivalent)
- **AND** at boot time, a file SHALL exist at that path containing the deterministic value
- **AND** the service SHALL start successfully reading that file

#### Scenario: Binary-format secrets receive hex-encoded hash content
- **GIVEN** a VM test node that declares `sops.secrets.wireguard = { format = "binary"; };`
- **WHEN** the secret is evaluated
- **THEN** the VM test profile SHALL write the same deterministic hash string as text-format secrets: `"test-${builtins.hashString "sha256" name}"`
- **AND** the content SHALL be written via `systemd.tmpfiles.rules` (same mechanism as text secrets, no `pkgs.runCommand` needed)
- **AND** binary consumers SHALL receive the hex-encoded hash as file content, which is deterministic, consistent, and compatible with tmpfiles text file creation
- **AND** the file content SHALL be identical across any test node that declares a secret with the same key path, regardless of `format` attribute

#### Scenario: Secret path accessible before sops activation service runs
- **GIVEN** a VM test node with sops-dependent systemd services
- **WHEN** the system boots and services attempt to start
- **THEN** the secret files SHALL exist at `config.sops.secrets.<name>.path` before any sops activation service runs
- **AND** services SHALL NOT fail with "file not found" errors due to missing sops decryption
- **AND** `systemd.tmpfiles.rules` SHALL create the secret files at boot, before any sops-dependent services start

### Requirement: No real secrets in repository or test artifacts

The system SHALL ensure that the deterministic secret generation mechanism introduces no real secret material into the repository, the Nix store, or VM test artifacts.

#### Scenario: No real secrets committed
- **WHEN** the VM test profile generates dummy secrets
- **THEN** the derivation SHALL NOT read or reference any `.sops.yaml`, `secrets.yaml`, age key files, or any other file containing real secret material
- **AND** the repository SHALL contain no real secret material as a result of the VM test secret generation mechanism

#### Scenario: Nix store contains only deterministic dummy data
- **WHEN** a VM test node configuration is built (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel`)
- **THEN** the resulting store paths SHALL contain only the deterministic hash-derived dummy values
- **AND** SHALL NOT contain any production secret material

### Requirement: Sops-nix activation does not fail due to missing age keys

The VM test profile SHALL override the sops-nix activation mechanism so that the system boots successfully without real age keys, while still satisfying all module references to `config.sops.secrets.<name>`. The profile SHALL set `sops.age.keyFile = "/dev/null"` (satisfies sops-nix's eval-time key-source assertion without allowing real decryption), set `sops.gnupg.home = null`, `sops.gnupg.sshKeyPaths = []` for explicit GnuPG clarity, and set `sops.validateSopsFiles = false` to prevent build-time file-format errors.

#### Scenario: Missing age keys do not block boot
- **GIVEN** a VM test node configured with the VM test profile
- **WHEN** the node boots
- **THEN** `sops.age.keyFile` SHALL be set to `"/dev/null"` (satisfies sops-nix eval-time assertion, file exists but decrypts nothing)
- **AND** `sops.age.sshKeyPaths` SHALL be set to `[]`
- **AND** `sops.gnupg.home` SHALL be set to `null`
- **AND** `sops.gnupg.sshKeyPaths` SHALL be set to `[]`
- **AND** `sops.validateSopsFiles` SHALL be set to `false`
- **AND** the sops-nix activation service SHALL NOT attempt to decrypt secrets using age keys
- **AND** the system SHALL reach `multi-user.target` without errors related to sops decryption

#### Scenario: Sops secrets module evaluates without activation service
- **GIVEN** a VM test node
- **WHEN** the sops secrets module evaluates
- **THEN** `config.sops.secrets.<name>` SHALL contain a valid `.path` attribute for every declared secret
- **AND** the evaluation SHALL succeed with `sops.age.keyFile = "/dev/null"`, `sops.age.sshKeyPaths = []`, `sops.gnupg.home = null`, `sops.gnupg.sshKeyPaths = []`, and `sops.validateSopsFiles = false`
- **AND** the evaluation SHALL NOT trigger a build-time error from sops-nix for missing age configuration
- **AND** the `"/dev/null"` key file SHALL satisfy sops-nix's internal assertion that at least one key source is present

### Requirement: sops.placeholder and sops.templates resolve automatically in test VMs

The sops-nix `sops.placeholder.<name>` and `sops.templates.<name>` features SHALL work in VM test nodes without any special configuration in the test profile. These features return deterministic placeholder values when no real decryption keys are available, which is automatically satisfied by the test profile's `sops.age.keyFile = "/dev/null"` setup.

#### Scenario: Placeholder values resolve without real keys
- **GIVEN** a VM test node that uses `sops.placeholder."SOME/PLACEHOLDER"` or `sops.templates."SOME/TEMPLATE"` in its service configuration
- **WHEN** the NixOS module system evaluates the configuration
- **THEN** the placeholder or template SHALL resolve to a deterministic placeholder value without any real decryption keys
- **AND** no special configuration, override, or workaround SHALL be required in the VM test profile for these features to work
- **AND** services that consume `sops.placeholder` or `sops.templates` values (e.g., monitoring, MCPO, coder) SHALL function identically in VM tests as in production, using the placeholder value

### Requirement: Secret generation mechanism is scoped to VM test profile

The deterministic secret value logic SHALL be activated only when the VM test profile (`tests/profiles/vm-test.nix`) is imported into a NixOS configuration, and SHALL NOT affect production builds.

#### Scenario: Production builds use real sops decryption
- **GIVEN** a host built for production deployment (not as a VM test node)
- **WHEN** the sops secrets module evaluates
- **THEN** the VM test profile's `systemd.tmpfiles.rules` and `pkgs.runCommand` derivation SHALL NOT be active
- **AND** `sops.age.sshKeyPaths` SHALL retain its default value (real SSH keys for decryption)
- **AND** `sops.validateSopsFiles` SHALL be `true` (default)
- **AND** secret resolution SHALL proceed via normal sops-nix decryption from encrypted `.sops.yaml` files
- **AND** production builds SHALL remain unaffected by the VM test secret generation mechanism
