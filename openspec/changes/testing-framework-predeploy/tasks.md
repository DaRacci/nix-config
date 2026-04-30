## 1. CI harness and evaluation plumbing

- [ ] 1.1 Expose `vm-test-<host>` checks for all server hosts from the CI flake partition using `pkgs.testers.runNixOSTest`
- [ ] 1.2 Ensure host discovery for the harness is derived from repository host data rather than static hostname wiring
- [ ] 1.3 Verify the CI checks output lists every server VM test attribute

## 2. VM compatibility and secret handling

- [ ] 2.1 Add a test-only VM profile that replaces or disables Proxmox LXC-specific behavior for test nodes only
- [ ] 2.2 Add a test-only secret generation module that provides dummy runtime secret files at the paths expected by sops consumers
- [ ] 2.3 Verify representative VM evaluations succeed without proxmox-lxc or missing-sops-key errors

## 3. Baseline and service-aware test modules

- [ ] 3.1 Add a baseline VM test module that validates boot readiness, SSH, firewall state, journald persistence, and failed-unit handling
- [ ] 3.2 Add service-aware test selection for proxy, postgres, monitoring collector, and tailscale based on evaluated host configuration
- [ ] 3.3 Add test-only local service enablement where single-host VM validation requires local dependencies

## 4. PR-gated CI integration and docs

- [ ] 4.1 Add a PR-only Woodpecker VM test workflow for KVM-capable runners that builds per-host VM test checks
- [ ] 4.2 Add `docs/src/development/vm_integration_tests.md` and link it from `docs/src/SUMMARY.md`
- [ ] 4.3 Verify representative `nix eval` and `nix build` commands for VM tests and confirm docs are linked
