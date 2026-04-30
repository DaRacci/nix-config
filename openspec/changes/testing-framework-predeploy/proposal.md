## Why

The server fleet currently lacks a pre-deploy integration test framework that validates real host behavior before changes land, especially for services that depend on NixOS module composition and secret wiring. A CI-only VM testing framework is needed now so pull requests can prove server functionality without relying on real secrets, Proxmox LXC runtime, or manual deployment checks.

## What Changes

- Add a CI-partition VM test harness that exposes per-server `runNixOSTest` checks for all server hosts.
- Add VM-only profile overrides so server configurations designed for Proxmox LXC can evaluate and boot under QEMU-backed NixOS tests.
- Add test-only secret generation that satisfies sops-based modules without using real secrets in CI.
- Add baseline and service-aware VM test modules selected from host configuration state.
- Add a Woodpecker PR-only VM test workflow for KVM-capable runners.
- Add documentation describing test structure, auto-detection, local execution, and CI behavior.

## Non-goals

- Modifying production host configurations solely to make tests easier to run.
- Adding multi-VM cluster simulation for this initial iteration.
- Wiring VM tests into default `nix flake check` or non-PR local workflows.
- Using real sops keys or production secrets in CI.
- Replacing deployment validation with push-time or post-merge scripts outside the CI PR path.

## Capabilities

### New Capabilities
- `server-vm-test-harness`: Expose per-server VM integration test checks from the CI flake partition.
- `vm-test-profile-overrides`: Adapt server configurations for VM-based tests without changing production host modules.
- `vm-test-secret-generation`: Provide runtime-generated secrets for test environments that satisfy sops-dependent modules.
- `service-aware-vm-tests`: Attach baseline and per-service test behaviors according to evaluated host configuration.
- `woodpecker-vm-test-gating`: Run VM test checks only for pull requests on KVM-enabled Woodpecker runners.
- `vm-test-documentation`: Document test architecture, auto-detection, overrides, and local usage.

### Modified Capabilities

None.

## Impact

- Affected code: `flake/ci/`, possible new `modules/nixos/testing/`, `tests/nixos/`, `.woodpecker/`, and `docs/src/development/`.
- Affected systems: CI checks output, Woodpecker PR runners with `/dev/kvm`, and server-oriented NixOS test derivations.
- Affected configurations: server hosts `nixai`, `nixarr`, `nixcloud`, `nixdev`, `nixio`, `nixmon`, and `nixserv`; no Home Manager configurations are in scope.
- External dependencies: QEMU-backed `runNixOSTest`, KVM availability in CI, and existing server module state used for service auto-detection.
