---
name: building
description: Build and evaluate NixOS and Home-Manager configurations
---

# Building

## Build Commands

| Command                                                               | Purpose                              |
| --------------------------------------------------------------------- | ------------------------------------ |
| `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` | Build host NixOS system              |
| `nix build .#homeConfigurations.<user>@<host>.activationPackage`      | Build Home-Manager activation        |
| `nix fmt`                                                             | Format code and check syntax         |
| `nix flake check`                                                     | Evaluate all configs and run linters |
| `nix flake show`                                                      | Show available outputs               |
| `nix develop`                                                         | Open dev shell                       |
| `nix develop --command true`                                          | Check devShell can open              |

## DevEnv Requirement

Repo uses `devenv` for devShells and checks. You **must** pass `devenv-root` override for `nix flake check` and `nix develop`:

```bash
nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"

nix develop --override-input devenv-root "file+file://$PWD/.devenv/root"
```

## Common Build Patterns

### Build specific host

```bash
# Build nixdev server
nix build .#nixosConfigurations.nixdev.config.system.build.toplevel

# Build nixmi desktop
nix build .#nixosConfigurations.nixmi.config.system.build.toplevel
```

### Build user home config

```bash
# Build racci config on nixmi
nix build .#homeConfigurations."racci@nixmi".activationPackage
```

### Evaluate without building

```bash
# Check config evaluates
nix eval .#nixosConfigurations.nixdev.config.system.build.toplevel --apply 'x: "ok"'

# Get specific option value
nix eval .#nixosConfigurations.nixdev.config.networking.hostName
```

### Format specific files

```bash
# Format changed file
nix fmt path/to/file.nix

# Format multiple files
nix fmt modules/nixos/services/*.nix
```

## Troubleshooting Builds

If build fails:

1. Check error message for failing derivation
2. Run `nix log <drv>` to see build logs
3. Use `--show-trace` for eval errors: `nix build .#... --show-trace`
4. For infinite recursion, check circular imports or option definitions
