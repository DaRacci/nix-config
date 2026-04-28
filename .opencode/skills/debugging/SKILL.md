---
name: debugging
description: Troubleshoot Nix evaluation and build errors
---

# Debugging

## Evaluation Debugging

### Using builtins.trace

Add trace statements to see values during evaluation:

```nix
let
  myValue = builtins.trace "myValue is: ${toString someVar}" someVar;
in
# myValue prints during evaluation
```

For complex values:

```nix
builtins.trace (builtins.toJSON someAttrSet) someAttrSet
```

### Using nix eval

Test expressions without building:

```bash
# Evaluate specific option
nix eval .#nixosConfigurations.nixdev.config.networking.hostName

# Check if something evaluates
nix eval .#nixosConfigurations.nixdev.config.services.nginx.enable

# Evaluate with trace output visible
nix eval .#nixosConfigurations.nixdev.config.system.build.toplevel --apply 'x: "ok"'
```

### Show trace on error

```bash
nix build .#nixosConfigurations.nixdev.config.system.build.toplevel --show-trace
```

## Common Errors

### Infinite recursion

**Error**: `infinite recursion encountered`

**Causes**:
- Circular imports between modules
- Option depends on itself
- Config references options that reference config

**Fix**: Check imports and option definitions for circular dependencies.

### Attribute not found

**Error**: `attribute 'foo' missing`

**Causes**:
- Typo in attribute name
- Missing import
- Wrong option path

**Fix**:
```bash
# List available attributes
nix eval .#nixosConfigurations.nixdev.config.services --apply 'builtins.attrNames'
```

### Type mismatch

**Error**: `value is a string while a list was expected`

**Causes**:
- Wrong type for option
- Incompatible merge of values

**Fix**: Check option type definition and provided value.

### Assertion failed

**Error**: `assertion ... failed`

**Causes**:
- Config constraint not met
- Required option missing

**Fix**: Read assertion message and provide required config.

## Build Debugging

### View build logs

```bash
# For failed derivation
nix log /nix/store/...-derivation.drv

# Or from error output
nix log <drv-path-from-error>
```

### Build with verbose output

```bash
nix build .#package -L
```

### Enter build environment

```bash
nix develop .#nixosConfigurations.nixdev.config.system.build.toplevel
```

## Module Debugging

### Check if module is imported

```bash
nix eval .#nixosConfigurations.nixdev.config.services.myService.enable
```

### List all options in namespace

```bash
nix eval .#nixosConfigurations.nixdev.options.services.myService --apply 'builtins.attrNames'
```

### Check option definition location

```bash
nix eval .#nixosConfigurations.nixdev.options.services.nginx.enable.definitionsWithLocations
```

## Flake Debugging

### Check flake syntax

```bash
nix flake check --no-build
```

### Show flake structure

```bash
nix flake show
```

### Evaluate specific output

```bash
nix eval .#nixosConfigurations --apply 'builtins.attrNames'
nix eval .#homeConfigurations --apply 'builtins.attrNames'
```

## Quick Diagnostics

| Problem | Command |
|---------|---------|
| Does it evaluate? | `nix eval .#... --apply 'x: "ok"'` |
| What options exist? | `nix eval .#...options --apply 'builtins.attrNames'` |
| What is value? | `nix eval .#...config.<path>` |
| Where is error? | `nix build --show-trace` |
| What failed in build? | `nix log <drv>` |
| Is syntax valid? | `nix flake check --no-build` |