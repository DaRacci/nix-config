## Context

The source plan defines VM integration tests as a CI-only enforcement mechanism for all server hosts. The notepad learnings add two important implementation constraints: the flake uses `flake-parts` partitions, so `checks` had to move into the `ci` partition to expose VM test outputs, and JJ or direnv environments can leave broken `NIX_*` variables around while evaluating commands. The intended framework must validate real host behavior in a VM, work around Proxmox LXC assumptions, generate fake runtime secrets, and select service-specific tests from configuration rather than hostname-specific rules.

This is a cross-cutting Nix change touching flake outputs, test-only modules, NixOS test definitions, CI execution, and docs, so a formal design is warranted.

### Component Diagram

```text
Server host configs
      |
      v
CI flake partition checks
      |
      v
VM harness builder ----> VM profile overrides
      |                        |
      |                        v
      |                  test-only secret module
      |
      v
baseline + service-aware test modules
      |
      v
Woodpecker PR pipeline on KVM runner
```

## Goals / Non-Goals

**Goals:**

- Expose VM test checks for every server host through CI flake outputs.
- Make LXC-oriented server configs evaluable and bootable in NixOS VMs without production edits.
- Generate runtime dummy secrets that satisfy sops-dependent modules during tests.
- Combine baseline system assertions with per-service tests derived from enabled options.
- Run the resulting tests only in Woodpecker PR workflows on KVM-capable runners.

**Non-Goals:**

- Building a full multi-host integration lab for database or network topologies.
- Moving VM tests into local default developer flows or `nix flake check`.
- Reworking production module architecture beyond test-only override points.
- Using real deployment secrets, keys, or Proxmox infrastructure in CI.

## Decisions

### Decision 1: Expose VM tests from the CI partition

**Choice:** Define `vm-test-<host>` checks in the `ci` partition rather than the `dev` partition or default flake checks.

**Rationale:** The notepad confirms `checks` moved into the CI partition so VM outputs are visible. This keeps expensive VM tests in the intended CI boundary and out of local default flake checks.

**Alternatives considered:**

- Add VM tests to `nix flake check`: rejected as too slow and contrary to the plan.
- Keep checks in `dev`: would not expose the desired CI outputs cleanly.

### Decision 2: Use a test-only VM profile to override LXC assumptions

**Choice:** Inject a VM-specific module into test nodes that disables or replaces Proxmox LXC settings and supplies VM-safe defaults.

**Rationale:** The source plan explicitly rejects modifying host configs under `hosts/server/*` just to make tests pass. A test-only profile contains the compatibility layer in one place.

**Alternatives considered:**

- Remove LXC assumptions from production hosts: too invasive for a testing feature.
- Mock away boot differences without a profile: insufficient for realistic VM tests.

### Decision 3: Generate dummy runtime secrets instead of decrypting sops data

**Choice:** Add a test-only module that materializes the expected secret paths at runtime under `/run/secrets` and points sops-dependent consumers at those files.

**Rationale:** The plan requires zero real secrets in CI while still exercising modules that expect `config.sops.secrets.*.path`. Runtime generation satisfies both constraints.

**Alternatives considered:**

- Commit fake secret files: too close to production patterns and easy to misuse.
- Disable secret-dependent modules in tests: reduces fidelity and hides integration failures.

### Decision 4: Keep tests single-host but run dependent services locally in the VM

**Choice:** For hosts whose production behavior depends on aggregated or remote services, force the required service up locally inside the single test VM rather than building a cluster test.

**Rationale:** The plan rejects multi-VM cluster work in this iteration, but also rejects pure mocks for cases like database checks. Local-in-VM service enablement preserves more realistic validation without broadening scope.

**Alternatives considered:**

- Multi-node integration test topology: higher realism, but explicitly out of scope.
- Pure config introspection without booted services: insufficient behavioral coverage.

### Decision 5: Select service checks from evaluated configuration

**Choice:** Map enabled options such as proxy, postgres, monitoring collector, and tailscale state to corresponding test modules and attach them automatically to each host's VM test.

**Rationale:** This keeps the framework host-agnostic, aligns with the plan, and avoids brittle hostname lists.

## Risks / Trade-offs

**[Partition drift]** -> Moving checks into the CI partition can hide or displace other checks such as treefmt outputs.  
*Mitigation:* Keep the change explicit in flake docs and verify any displaced checks separately.

**[LXC to VM mismatch]** -> Some host assumptions may still leak through the override profile.  
*Mitigation:* Centralize overrides in a dedicated VM profile and expand it incrementally as incompatibilities are discovered.

**[Secret fidelity gap]** -> Dummy secrets validate path wiring, but not the correctness of real secret values.  
*Mitigation:* Treat this framework as pre-deploy structural validation, not a substitute for runtime production secret correctness.

**[KVM availability]** -> VM test throughput and reliability depend on Woodpecker runners exposing `/dev/kvm`.  
*Mitigation:* Gate the workflow to KVM-capable runners and document the requirement clearly.

## Migration Plan

1. Add CI-partition VM harness outputs for all server hosts.
2. Add the VM override profile and generated-secrets module.
3. Add baseline and service-aware test modules.
4. Wire the PR-only Woodpecker workflow.
5. Document usage and extension points.
6. Roll back by removing the new CI outputs and test modules; production host configuration remains unchanged.

### Sequence Diagram

```text
Pull request -> Woodpecker PR workflow: start VM test job
Woodpecker -> flake CI partition: evaluate vm-test-<host> checks
CI partition -> VM harness: assemble host node with test overrides
VM harness -> test-only modules: add VM profile + generated secrets
VM harness -> service-aware modules: attach baseline and selected service checks
VM test -> Woodpecker: report pass/fail for each server host
```

## Open Questions

1. Whether all displaced non-VM checks need a separate documented location after the `checks` partition move.
2. Which service families beyond postgres, proxy, monitoring collector, and tailscale should be included in the first auto-detection pass.
3. Whether affected-host selection should be introduced immediately or deferred in favor of always running all server VM tests.
