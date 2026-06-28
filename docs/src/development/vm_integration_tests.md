# VM Integration Tests

Pre-deploy NixOS VM integration tests for server hosts. These tests wrap production host
configurations with VM-compatible overrides and run inside QEMU virtual machines to
validate boot, service startup, and configuration correctness before deployment.

## Architecture

VM tests live under the top-level flake attribute `nixosTestConfigurations`, parallel
to `nixosConfigurations`. Each entry is a NixOS VM test derivation built with
`pkgs.testers.runNixOSTest`.

```
flake.nix
├── nixosConfigurations/   # Production host configs (nixio, nixai, ...)
└── nixosTestConfigurations/   # VM test derivations
    ├── nixio              # Auto-discovered per-host test
    ├── nixai              # Auto-discovered per-host test
    └── postgres-backup    # Explicit scenario test
```

### Relationship to `nixosConfigurations`

Each `nixosTestConfigurations.<host>` entry wraps the corresponding production
`nixosConfigurations.<host>` with test-only overrides from `tests/profiles/vm-test.nix`.
The naming convention mirrors `nixosConfigurations` intentionally — `nixosTestConfigurations.nixio`
tests the same host that `nixosConfigurations.nixio` deploys.

### Relationship to `checks.cluster`

The existing `checks.cluster` (in `flake/ci/flake-module.nix`) is a single multi-node test
that boots all 7 server hosts simultaneously and verifies they reach `multi-user.target`.
It remains unchanged. `nixosTestConfigurations` complements it with:

- **Per-host isolation:** test a single host without booting the entire fleet
- **Service-aware checks:** auto-discovered `server.tests.units` for service-specific validation
- **Explicit scenarios:** multi-node tests for cross-service interactions (e.g., postgres backup)

### Why not under `checks`?

VM tests are **not** wired into `nix flake check`. Running `nix flake check` does NOT
execute VM tests. This is intentional — VM tests are expensive (QEMU boot per host) and
would slow down local development workflows. Instead, VM tests execute only in CI via a
separate Woodpecker workflow (`.woodpecker/test-vm.yaml`) on pull request events.

## Two Test Authoring Modes

### 1. Auto-Discovered Per-Host Tests

Any server host automatically gets a `nixosTestConfigurations.<host>` entry. The test
boots the host's full NixOS configuration with VM overrides applied and runs baseline
assertions: boot success, SSH availability, journald persistence, and no failed units.

To add service-specific tests to a host, use the existing `server.tests.units` option
in the host's configuration file. For example, in `hosts/server/nixio/database.nix`:

```nix
server.tests.units.postgres = {
  testScript = { config, ... }: ''
    nixio.succeed("sudo -u postgres psql -c 'SELECT 1'")
  '';
};
```

The test runs inside a named Python `subtest` block in the VM test. The `testScript`
function receives the node's evaluated NixOS config as its argument.

### 2. Explicit Scenario Tests

For cross-service or multi-node interactions, create a scenario file under
`tests/scenarios/<name>/test.nix`. Each scenario defines arbitrary NixOS nodes
and a `testScript`. The directory name becomes the `nixosTestConfigurations.<name>`
entry.

Example (`tests/scenarios/postgres-backup/test.nix`):

```nix
{
  nodes = {
    postgres-server = { pkgs, ... }: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "testdb" ];
        ensureUsers = [ { name = "testuser"; ensureDBOwnership = true; } ];
      };
    };
    postgres-client = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.postgresql ];
    };
  };

  testScript = ''
    postgres-client.wait_for_unit("multi-user.target")
    postgres-client.succeed(
        "psql -h postgres-server -U testuser -d testdb -c 'SELECT 1'"
    )
  '';
}
```

Scenario tests automatically apply the VM test profile to every node and run baseline
assertions before the scenario-specific `testScript`.

**Guideline:** Use `server.tests.units` for single-service behavior that can be
verified inside one VM. Use scenarios only when cross-service or multi-node
interaction is required.

## VM Test Profile

The module at `tests/profiles/vm-test.nix` is injected into every VM test node.
It contains the centralized policy for making production server configs compatible
with QEMU VMs.

### Disabled Services

Services that require real external credentials to operate are explicitly disabled
in test VMs. This is an accepted coverage gap — these services cannot meaningfully
validate in an isolated VM without real API keys or OAuth tokens.

| Service              | Reason                                                          |
| -------------------- | --------------------------------------------------------------- |
| `services.tailscale` | Needs a real auth key or OAuth client to join the tailnet       |
| `services.mcpo`      | Needs GitHub, AniList, and other OAuth tokens unavailable in CI |
| `services.ollama`    | Requires GPU passthrough (ROCm/CUDA) unavailable in QEMU VMs    |

### ProxmoxLXC Overrides

The test profile sets `proxmoxLXC.manageNetwork = false` and `proxmoxLXC.manageHostName = false`.
QEMU's test driver manages networking and hostname configuration for VM guests, so the
Proxmox LXC-specific flags must be disabled to avoid conflicts. The remaining production
host configuration evaluates without modification.

### Deterministic Sops Secrets

Test VMs cannot use real sops decryption keys. Instead, the profile generates
deterministic dummy secrets using `systemd.tmpfiles.rules`. Each `sops.secrets.<name>`
declared in a host configuration gets a file created at `config.sops.secrets.<name>.path`
with content derived from the secret key path:

```nix
"test-${builtins.hashString "sha256" name}"
```

This means:

- The same key path produces identical content across all test nodes — critical for
  shared secrets (DB passwords, API keys shared between hosts)
- Different key paths produce different values — services that depend on specific secrets
  can be validated for path wiring correctness
- No real secret material enters the Nix store or repository
- `sops.placeholder.<name>` and `sops.templates.<name>` continue to work — they return
  deterministic placeholder values when no real decryption keys are available

The profile also sets `sops.age.keyFile = "/dev/null"` (satisfies sops-nix's eval-time
assertion that at least one key source exists), clears GnuPG key paths, and disables
sops file validation at build time.

## Local Execution

Build and run a single host's VM test:

```bash
nix build .#nixosTestConfigurations.<host>
```

For example:

```bash
nix build .#nixosTestConfigurations.nixio
```

List all available test targets:

```bash
nix eval .#nixosTestConfigurations --apply 'builtins.attrNames'
```

### Requirements

- **`/dev/kvm`**: QEMU tests require KVM acceleration. Without it, tests will be
  impractically slow and may hang.
- **Nix**: Standard Nix with flake support.

These tests are NOT run by `nix flake check`.

## CI Behavior

VM tests execute in a separate Woodpecker workflow (`.woodpecker/test-vm.yaml`):

- **Trigger:** `pull_request` events only. Does NOT run on push, tag, or manual events.
- **Runner:** Requires a Woodpecker runner with the `kvm: true` label and `/dev/kvm` access.
- **Scope:** ALL server host VM tests run on every PR event. Affected-host selection
  (building only hosts changed by a PR) is deferred to a future iteration.
- **Independence:** The `test-vm.yaml` workflow does NOT affect the existing
  `check.yaml` workflow. A VM test failure does not block or alter `check.yaml` results.

### Adding a New Test

1. Decide on the test scope:
   - **Single service, one host:** Add `server.tests.units.<name>` to the service's
     host configuration file.
   - **Multi-node or cross-service:** Create a directory `tests/scenarios/<name>/`
     with a `test.nix` file.

1. The test appears automatically in `nixosTestConfigurations` — no registration needed.

1. Run locally to verify:

   ```bash
   nix build .#nixosTestConfigurations.<name>
   ```

### Disabled Service Tests

When a service is disabled by the VM test profile (e.g., `services.tailscale`),
its `server.tests.units` entries are silently skipped in per-host VM tests.
The rationale: services that are disabled cannot run, so their tests cannot pass.
These services are exercised by other means (integration tests on real infrastructure,
manual validation).
