---
name: testing
description: Test changes using module-graph and build commands
---

# Testing

## Critical Requirement

After making changes you **must always** evaluate and test them.

## Finding Affected Configurations

Use module-graph script to find which hosts and homes are affected by changed files:

```bash
nix run .#module-graph
```

This outputs JSON showing which configs use each file:

```json
{
  "file": "modules/nixos/services/tailscale.nix",
  "hosts": ["nixdev", "nixmi", "nixcloud"],
  "homes": []
}
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

2. Run module-graph to find affected configs:

   ```bash
   nix run .#module-graph | jq '.[] | select(.file | contains("tailscale"))'
   ```

3. Pick one affected host and build it:

   ```bash
   nix build .#nixosConfigurations.nixdev.config.system.build.toplevel
   ```

4. If change also affects homes, build one:
   ```bash
   nix build .#homeConfigurations."racci@nixmi".activationPackage
   ```
