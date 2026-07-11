---
name: testing
description: Test changes using module-graph and build commands
---

# Testing

## Critical Requirement

After making changes you **must always** evaluate and test them.

## Finding Affected Configurations

Use module-graph script with `--since` to find only hosts and homes affected by files changed since commit or ref. Add `--refine` to further narrow results for files under `modules/nixos/` and `modules/home-manager/` when module exposes `options.<path>.enable`:

```bash
SILENT=true nix run .#module-graph -- --since <COMMIT_HASH> --refine --report
```

This will output a report similar to the following, showing which hosts and homes are affected by the changes:

```text
*************************************************************
  NixOS HOSTS
*************************************************************

Priority: HIGH
  - nixai [5 modules]
  - nixserv [4 modules]

Priority: MEDIUM
  - nixdev [3 modules]

Priority: LOW
  - nixio [1 modules]

*************************************************************
  HOME-MANAGER CONFIGS
*************************************************************

Priority: LOW
  - racci [1 modules]
```

## Minimum Test Requirements

Based on module-graph output, test **at least one** of each affected type:

| Changed File Affects | Minimum Test                |
| -------------------- | --------------------------- |
| Hosts only           | Build one affected host     |
| Homes only           | Build one affected home     |
| Both hosts and homes | Build one host and one home |

## Test Commands

### Test host configuration

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### Test home configuration

```bash
nix build .#homeConfigurations."<user>@<host>".activationPackage
```

### Run full flake check

```bash
nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"
```

## Testing Workflow Example

1. Make changes to `modules/nixos/services/tailscale.nix`

2. Run module-graph with `--since` to find affected configs from your change range. Add `--refine` when you want enable-option based narrowing:

   ```bash
   nix run .#module-graph -- --since origin/main --refine | jq '.[] | select(.file | contains("tailscale"))'
   ```

3. Pick one affected host and build it:

   ```bash
   nix build .#nixosConfigurations.nixdev.config.system.build.toplevel
   ```

4. If change also affects homes, build one:
   ```bash
   nix build .#homeConfigurations."racci@nixmi".activationPackage
   ```
