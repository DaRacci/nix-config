# VM Integration Tests

Pre-deploy NixOS VM integration tests for server hosts. Wraps production host
configurations with VM-compatible overrides and runs inside QEMU virtual machines.
Validates boot, service startup, and configuration correctness before deployment.

## Architecture

VM tests are in the top-level flake attribute `nixosTestConfigurations`, parallel
to `nixosConfigurations`. Each entry is a NixOS VM test derivation built with
`pkgs.testers.runNixOSTest`.

```text
flake.nix
├── nixosConfigurations/      # Production host configs (nixio, nixai, ...)
└── nixosTestConfigurations/  # VM test derivations
    ├── nixio                 # Auto-discovered per-host test
    ├── nixai                 # Auto-discovered per-host test
    └── proxy-routing         # Explicit scenario test
```

### Relationship to `nixosConfigurations`

Each `nixosTestConfigurations.<host>` entry wraps the corresponding production
`nixosConfigurations.<host>` with test-only overrides from `tests/profiles/vm-test.nix`.
The naming convention mirrors `nixosConfigurations` — `nixosTestConfigurations.nixio`
tests the same host that `nixosConfigurations.nixio` deploys.

### Why not under `checks`?

VM tests are **not** wired into `nix flake check`. Running `nix flake check` does NOT
execute VM tests. VM tests are expensive (QEMU boot per host) and would slow down local
development. They execute only in CI via a separate Woodpecker workflow
(`.woodpecker/test-vm.yaml`) on pull request events.

## Testing Philosophy

Scenario tests exist to validate **custom modules and logic from this repository** —
not upstream nixpkgs module behavior. nixpkgs modules (postgresql, openssh,
prometheus, pgvector, etc.) are assumed correct; their behavior is tested by
nixpkgs upstream, not by this repo.

**Scenarios test custom logic only.** Examples of valid scenarios:

- `database-backup-chain/` — io-guardian managed cross-host pg_dump
- `firewall-port-audit/` — custom networking module
- `io-guardian/` — custom io-guardian module
- `proxy-routing/` — custom proxy/caddy TLS routing
- `redis-remote-connect/` — custom redis module

Auto-discovered per-host VM tests validate that **this repo's custom modules** work
correctly when composed with real production configurations. They are not unit tests
for nixpkgs services.

Sops secrets are auto-discovered from `config.sops.secrets` — no manual secret name
maintenance is needed.

## Two Test Authoring Modes

### 1. Auto-Discovered Per-Host Tests

Any server host automatically gets a `nixosTestConfigurations.<host>` entry. The test
boots the host's full NixOS configuration with VM overrides applied and runs baseline
assertions: boot success, SSH availability, journald persistence, no failed units.

To add service-specific tests to a host, use the existing `server.tests.units` option
in the host's configuration file. In `hosts/server/nixio/database.nix`:

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

For cross-service or multi-node interactions testing custom repository logic, create a
scenario file under `tests/scenarios/<name>/test.nix`. Each scenario defines arbitrary
NixOS nodes and a `testScript`. The directory name becomes the
`nixosTestConfigurations.<name>` entry.

Example (`tests/scenarios/proxy-routing/test.nix`):

```nix
{
  nodes = {
    nixio = { ... };     # caddy reverse proxy
    nixcloud = { ... };  # nextcloud backend
  };

  testScript = ''
    nixio.wait_for_unit("caddy.service")
    nixcloud.wait_for_unit("phpfpm-nextcloud.service")

    with subtest("proxy routes to backend"):
      out = nixio.succeed(
          "curl -sf -H 'Host: nc.racci.dev' http://nixcloud/"
      )
      assert "Nextcloud" in out, "proxy did not route to nextcloud"
  '';
}
```

Scenario tests automatically apply the VM test profile to every node and run baseline
assertions before the scenario-specific `testScript`.

Guideline: use `server.tests.units` for single-service behavior verifiable inside one
VM. Use scenarios only when cross-service or multi-node interaction is required.

## VM Test Profile

The module at `tests/profiles/vm-test.nix` is injected into every VM test node.
It applies the overrides needed to make production server configs compatible with
QEMU VMs.

### Disabled Services

Services that need real external credentials are explicitly disabled in test VMs.
These services cannot validate in an isolated VM without real API keys or OAuth tokens.

| Service              | Reason                                                          |
| -------------------- | --------------------------------------------------------------- |
| `services.tailscale` | Needs a real auth key or OAuth client to join the tailnet       |
| `services.mcpo`      | Needs GitHub, AniList, and other OAuth tokens unavailable in CI |
| `services.ollama`    | Requires GPU passthrough (ROCm/CUDA) unavailable in QEMU VMs    |

### ProxmoxLXC Overrides

The test profile sets `proxmoxLXC.manageNetwork = false` and `proxmoxLXC.manageHostName = false`.
QEMU's test driver manages networking and hostname configuration for VM guests, so the
Proxmox LXC-specific flags are disabled to avoid conflicts. The remaining production
host configuration evaluates without modification.

### Deterministic Sops Secrets

Test VMs cannot use real sops decryption keys. Instead, the profile generates
deterministic dummy secrets using `systemd.tmpfiles.rules`. Each `sops.secrets.<name>`
declared in a host configuration gets a file created at `config.sops.secrets.<name>.path`
with content derived from the secret key path:

```nix
"test-${builtins.hashString "sha256" name}"
```

Key properties:

- Same key path → identical content across all test nodes. Critical for shared secrets
  (DB passwords, API keys shared between hosts)
- Different key paths → different values. Services depending on specific secrets can
  validate path wiring correctness
- No real secret material enters the Nix store or repository
- `sops.placeholder.<name>` and `sops.templates.<name>` continue working. They return
  deterministic placeholder values without real decryption keys

The profile also sets `sops.age.keyFile = "/dev/null"` (satisfies sops-nix's eval-time
assertion that at least one key source exists), clears GnuPG key paths, and disables
sops file validation at build time.

## Local Execution

Build and run a single host's VM test:

```bash
nix build .#nixosTestConfigurations.<host>
```

```bash
nix build .#nixosTestConfigurations.nixio
```

List all available test targets:

```bash
nix eval .#nixosTestConfigurations --apply 'builtins.attrNames'
```

### Filtering Specific Tests

When debugging a single unit test, set `testFilter` to run only matching tests
instead of all `server.tests.units.*` entries for that host:

```bash
nix build .#nixosTestConfigurations.<host> \
  --override-input . '/path/to/this/repo?testFilter=postgres-connect'
```

Or by editing the flake-module locally:

```nix
builder {
  # ...
  testFilter = [ "postgres-connect" ];
}
```

`testFilter` is null by default (all tests run). When set to a list of strings,
only unit tests whose names appear in the list execute. Non-matching names are
silently skipped — baseline assertions still run.

### Requirements

- **`/dev/kvm`**: QEMU tests require KVM acceleration. Without it, tests are
  impractically slow and may hang.
- **Nix**: Standard Nix with flake support.

These tests are NOT run by `nix flake check`.

## CI Behavior

VM tests execute in a separate Woodpecker workflow (`.woodpecker/test-vm.yaml`):

- **Trigger:** `pull_request` events only. Does not run on push, tag, or manual events.
- **Runner:** Requires a Woodpecker runner with the `kvm: true` label and `/dev/kvm` access.
- **Scope:** ALL server host VM tests run on every PR event. Affected-host selection
  (building only hosts changed by a PR) is deferred to a future iteration.
- **Independence:** The `test-vm.yaml` workflow does not affect the existing
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
Disabled services cannot run, so their tests cannot pass. These services are
exercised by other means (integration tests on real infrastructure, manual validation).

### Per-Service Test Patterns

Component tests follow a layered testing strategy. The pattern varies by service type:

#### HTTP Services (caddy, dashy, grafana, etc.)

```nix
server.tests.units.minio = {
  testScript = ''
    nixio.succeed("curl -s http://localhost:9000/minio/health/live | grep -q 'ok'")
  '';
};
```

#### Database Services (postgresql, redis, elasticsearch)

```nix
server.tests.units.postgres-connect = {
  testScript = ''
    nixio.succeed("psql -U postgres -c 'SELECT 1'")
  '';
};
```

For QEMU tests, use trust authentication — `vm-test.nix` injects `host all all all trust`.

### Scenario Authoring Guidance

Scenarios define self-contained NixOS nodes testing custom repository logic. Each node must work without external infrastructure.

#### Naming

- Directory name under `tests/scenarios/<name>/` becomes the `nixosTestConfigurations.<name>` entry automatically
- Use kebab-case: `redis-remote-connect`, `database-backup-chain`

#### Custom Logic Rule

Scenarios MUST test custom modules from this repository, not upstream nixpkgs behavior.
A scenario that merely asserts "postgresql responds on port 5432" or "sshd has
PasswordAuthentication no" adds no value — that is nixpkgs upstream's responsibility.

Valid scenario scope:

- Cross-host interaction orchestrated by custom modules (io-guardian, proxy-routing)
- Custom module behavior (firewall-port-audit, database-backup-chain)
- Custom service integration (redis-remote-connect with repo's redis module)

#### Self-Contained Rule

Every service, secret, and dependency must be defined within the scenario nodes:

- **PostgreSQL**: Use trust authentication (`host all all all trust`) — no sops secrets
- **Firewall**: Open ports explicitly with `networking.firewall.allowedTCPPorts`
- **DNS**: Use NixOS test driver hostnames (node names resolve automatically)
- **Secrets**: Avoid sops. Use inline configs, empty passwords, or trust auth

#### Node Structure

```nix
{
  nodes = {
    server-node = { pkgs, ... }: {
      services.openssh.enable = true;  # baseline needs sshd
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        authentication = ''
          local all all trust
          host all all all trust
        '';
      };
      networking.firewall.allowedTCPPorts = [ 5432 ];
    };
    client-node = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.postgresql ];
    };
  };
  testScript = ''
    start_all()
    # subtests here
  '';
}
```

#### What NOT to do

- **Don't set `name`** — flake-module injects it from directory name
- **Don't import `vm-test.nix`** — builder handles that automatically
- **Don't reference `config.sops.secrets`** — no real secrets available
- **Don't use Cloudflare plugins in Caddy** — no API tokens
- **Don't expect GPU-accelerated services** — no GPU in QEMU
- **Don't test upstream nixpkgs behavior** — scenario tests are for custom logic only

#### Multi-node Communication

Nodes communicate via their NixOS test driver hostnames (the keys in `nodes`):

```nix
# client-node reaches server-node:
client-node.succeed("psql -h server-node -U testuser -d testdb -c 'SELECT 1'")
```

IP assignment and DNS are handled automatically by the test driver. No manual IP configuration needed.
