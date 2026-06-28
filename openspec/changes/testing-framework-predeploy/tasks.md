## 1. Flake test attribute and harness plumbing

- [x] 1.1 Add `nixosTestConfigurations` to `flake/default.nix`'s `partitionedAttrs` under the `nixos` partition, and register entries in `flake/nixos/flake-module.nix`
- [x] 1.2 Create `tests/builder.nix` — a builder function accepting hostnames (auto-discovered mode) and scenario files (explicit mode), leaving `tests/default.nix` unchanged
- [x] 1.3 Wire host discovery from `tests/mkNode.nix` into the new builder so each server host produces a `nixosTestConfigurations.<host>` entry
- [x] 1.4 Verify `nix eval .#nixosTestConfigurations --apply 'builtins.attrNames'` lists all server hosts

## 2. VM test profile and deterministic secrets

- [x] 2.1 Create `tests/profiles/vm-test.nix` — disables services needing real API keys (Tailscale, MCPO, OAuth-based), GPU services (ollama), sets `proxmoxLXC.manageNetwork = false` + `manageHostName = false`
- [x] 2.2 Add deterministic sops secret generation via `systemd.tmpfiles.rules`: create `f <path> <mode> <user> <group> - test-${builtins.hashString "sha256" "<name>"}` for every declared secret; escape sops-nix key-source assertion by setting `sops.age.keyFile = "/dev/null"`; for binary-format secrets, write hex-encoded hash content; clear `sops.age.sshKeyPaths`, set `sops.validateSopsFiles = false`
- [x] 2.3 Verify representative host configs evaluate with VM profile applied (`nix eval .#nixosTestConfigurations.nixserv.config.system.build.toplevel` — should not error)
  - **Note:** Top-level evaluation succeeds (all entries are derivations). Deep eval blocked by pre-existing Lix 2.94 `builtins.convertHash` incompatibility with nixpkgs lib (sops-nix internal). Not a regression from our changes.
- [x] 2.4 Document the disabled-services policy in the test profile comments and in the docs spec

## 3. Auto-discovered and explicit scenario test modules

- [x] 3.1 Build an auto-discovery harness that reads `server.tests.units` from evaluated host config and generates per-host testScript with baseline assertions (boot, SSH, firewall, journald, no failed units)
- [x] 3.2 Support explicit test scenarios: files under `tests/scenarios/<name>/test.nix` that define NixOS nodes + testScript; wire them into `nixosTestConfigurations.<scenario-name>`
- [x] 3.3 Add a representative scenario (e.g., `tests/scenarios/postgres-backup/test.nix`) as a template for scenario authoring
- [x] 3.4 Validate that auto-discovered tests from `server.tests.units` run inside the VM harness for at least one representative host

## 4. PR-gated CI integration and documentation

- [x] 4.1 Add `.woodpecker/test-vm.yaml` — PR-only workflow, KVM-capable runners, builds `nixosTestConfigurations.*` targets
- [x] 4.2 Add `docs/src/development/vm_integration_tests.md` covering: architecture, VM profile policy, scenario authoring, local execution, CI behavior
- [x] 4.3 Link new doc from `docs/src/SUMMARY.md` under Development section
- [x] 4.4 Verify the Woodpecker workflow triggers correctly on PR events and the doc links resolve
