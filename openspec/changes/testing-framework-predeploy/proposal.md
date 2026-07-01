## Why

The 7-server fleet needs pre-deploy integration tests that validate real host behavior before changes land, especially for services that depend on NixOS module composition, secret wiring, and cross-host orchestration.

The project already has a working cluster integration test (`checks.cluster` in the CI partition) that boots all 7 server hosts under QEMU via `pkgs.testers.runNixOSTest`, using the existing `server.tests.units` option set (`modules/nixos/server/tests.nix`) for per-service test scripts. This infrastructure proves that:

- All server configs evaluate without VM override profiles — no Proxmox-specific barrier exists.
- sops-nix modules load fine without real keys — evaluation does not require decryption.

What's missing is a structured framework that makes it easy to write, discover, and run individual VM tests beyond the single all-nodes cluster smoke test. Today `checks.cluster` is a monolithic black-box: pass/fail on the whole fleet. There is no way to test a single service or host in isolation, no auto-discovery from host config, no policy for handling services that require real external API keys, and no deterministic secret derivation for cross-host consistency in test environments.

## What Changes

- **New flake attribute `nixosTestConfigurations`** — mirrors the `nixosConfigurations` naming convention. These are NixOS VM test derivations built with `pkgs.testers.runNixOSTest`. They live outside `checks` so `nix flake check` does not run them, though CI can still invoke them explicitly.

- **Test directory restructure under root-level `tests/`** — test code consolidates at `tests/` (already the home of the cluster test). A richer layout:

  ```
  tests/
    default.nix           # Existing cluster test (all 7 hosts)
    lib.nix               # Existing test helpers
    mkNode.nix            # Existing node construction
    profiles/             # Test-only NixOS modules
      vm-test.nix         # VM profile: disables API-key services, sops overrides
    scenarios/            # Explicit multi-node test scenarios
      <name>/             # Per-scenario directory
        test.nix          #   Scenario definition
    discover.nix          # Auto-discovery helper: generates per-host VM tests
  ```

- **Two test authoring modes:**

  1. **Auto-discovered from host config.** If a host enables `server.tests.units` (existing option in `modules/nixos/server/tests.nix`), a corresponding `nixosTestConfigurations.<host>` entry is generated automatically, wrapping the host config with test-only overrides.

  2. **Explicit test case files.** A file like `tests/scenarios/<name>/test.nix` defines "x machines with x configuration" — arbitrary topologies with overridden configs, not tied to a single production host.

- **Test-only profile overrides** — a new NixOS module `tests/profiles/vm-test.nix` that applies to test VMs only:

  - Disables services that need real external API keys to meaningfully validate:
    - Tailscale (needs real auth key / OAuth client)
    - MCPO with GitHub or AniList tokens
    - Any service configured with OAuth secrets that would attempt outbound connections to real providers
  - Provides deterministic sops secret generation: secrets derive their file content from the key path using `systemd.tmpfiles.rules` (e.g., `"f ${config.sops.secrets.<name>.path} 0400 root root - test-${builtins.hashString "sha256" "<name>"}"`). For binary secrets, a `pkgs.runCommand` derivation writes raw hash bytes. This makes cross-server secrets (shared DB passwords, API keys shared between hosts) consistent and predictable without real sops keys, and avoids using a non-existent `sops.secrets.<name>.value` option.
  - Sets VM-appropriate resources (CPU, memory, virtio) so hosts boot under QEMU.

  This is a **formal policy**: services that require real external credentials to function are explicitly disabled in test VMs. The override module documents every disabled service and the reason.

- **Woodpecker PR workflow** — a KVM-capable runner executes `nixosTestConfigurations` for all server hosts on pull requests (affected-host selection deferred to future iteration). Not wired into `nix flake check`.

- **Documentation** in `docs/src/development/vm_integration_tests.md` covering:
  - Architecture and directory layout
  - Writing auto-discovered vs. explicit tests
  - The external-service-disabled policy (what gets disabled and why)
  - Deterministic sops secrets in test environments
  - Local execution (`nix build .#nixosTestConfigurations.<host>`)
  - CI behavior (Woodpecker PR workflow, non-blocking on `nix flake check`)

## Non-goals

- Wiring VM tests into default `nix flake check` or non-PR local workflows.
- Modifying production host configurations solely to make tests easier to run.
- Multi-VM cluster simulation beyond what the existing `checks.cluster` already provides (for now).
- Using real sops keys or production secrets in CI.
- Replacing deployment validation with push-time or post-merge scripts outside the CI PR path.
- Running VM tests for every single host on every PR — only affected hosts (via change detection) execute.
- Replacing the existing `checks.cluster` or `server.tests.units` infrastructure — the new framework extends them.

## Capabilities

### New Capabilities

- `nixos-test-configurations`: New top-level flake attribute (`nixosTestConfigurations`) with VM test derivations for server hosts, discoverable by name and separate from `checks`.
- `vm-test-profile`: NixOS module (`tests/profiles/vm-test.nix`) applying test-only overrides: disables services needing real external API keys, provides deterministic sops secret derivation, and sets VM-appropriate resources.
- `explicit-test-scenarios`: Support for standalone test case files in `tests/` defining arbitrary multi-machine topologies with custom configs.
- `auto-discovered-tests`: Automatic generation of `nixosTestConfigurations` entries from hosts that declare `server.tests.units`.
- `woodpecker-vm-test-gating`: Woodpecker PR workflow for KVM-capable runners executing VM tests for changed hosts only.
- `vm-test-documentation`: Document test architecture, auto-discovery, overrides, writing tests, and local/CI usage.

### Modified Capabilities

- `cluster-test`: Existing `checks.cluster` (all 7 nodes) remains unchanged but is now complemented by granular per-host and per-service tests under `nixosTestConfigurations`.
- `server-tests-units`: Existing `server.tests.units` option (`modules/nixos/server/tests.nix`) gains a new role as the discovery hook for auto-generated VM test entries.

## Impact

- Affected code: `tests/` (new service/ scenario files + `profiles/vm-test.nix` + `discover.nix`), `flake/default.nix` (partitionedAttrs), `flake/ci/` (add `nixosTestConfigurations`), `.woodpecker/` (PR VM test workflow), `docs/src/development/vm_integration_tests.md`.
- Affected systems: CI flake outputs gain `nixosTestConfigurations`; Woodpecker PR runners with `/dev/kvm`; production server modules are **not** modified — all overrides live in the test profile.
- Affected configurations: server hosts `nixai`, `nixarr`, `nixcloud`, `nixdev`, `nixio`, `nixmon`, `nixserv` — each gets a discoverable VM test entry. Home Manager configurations are not in scope.
- External dependencies: QEMU-backed `runNixOSTest`, KVM availability in Woodpecker CI, existing `tests/default.nix` + `modules/nixos/server/tests.nix` infrastructure.
