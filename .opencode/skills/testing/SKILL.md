---
name: testing
description: Test changes using module-graph and build commands
---

# Testing

## Critical Requirement

After making changes you **MUST ALWAYS** evaluate and test your changes.

## Finding Affected Configurations

Use the module-graph script to determine which hosts and homes are affected by your changes:

```bash
./flake/dev/scripts/module-graph.nu
```

This outputs JSON showing which configurations use each file:

```json
{
  "file": "modules/nixos/services/tailscale.nix",
  "hosts": ["nixdev", "nixmi", "nixcloud"],
  "homes": []
}
```

## Minimum Test Requirements

Based on the module-graph output, you must test **at least one** of each type affected:

| Changed File Affects | Minimum Test |
|---------------------|--------------|
| Hosts only | Build one affected host |
| Homes only | Build one affected home |
| Both hosts and homes | Build one host AND one home |

## Test Commands

### Test a host configuration

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### Test a home configuration

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
   ./flake/dev/scripts/module-graph.nu | jq '.[] | select(.file | contains("tailscale"))'
   ```

3. Pick one affected host and build:
   ```bash
   nix build .#nixosConfigurations.nixdev.config.system.build.toplevel
   ```

4. If the change also affects homes, build one:
   ```bash
   nix build .#homeConfigurations."racci@nixmi".activationPackage
   ```

5. Format your changes:
   ```bash
   nix fmt modules/nixos/services/tailscale.nix
   ```
