# Repository Guidelines for Agents

Quick reference for agents working on this Nix-based configuration repository.
Load skills as needed for detailed guidance on specific tasks.

## CRITICAL OPERATIONAL RULES

These rules take **absolute precedence** over any other considerations. Violating these rules is unacceptable under any circumstances.

#### 1. 📝 Documentation Synchronization (MANDATORY)

```
RULE: Documentation in docs/ MUST be updated simultaneously with code changes.
STATUS: Non-negotiable. No exceptions.
VERIFICATION: Always check docs/ before completing any task.
```

**Process:**

1. Make code change in relevant `.nix` file
1. **IMMEDIATELY** update corresponding documentation in `docs/`
1. Verify documentation accurately reflects new behavior
1. Only then proceed to commit

**Example:**

```
If you modify: modules/nixos/services/tailscale.nix
You MUST update: docs/modules/nixos/services/tailscale.md
```

#### 2. 🧹 Code Formatting (MANDATORY)

```
RULE: All code MUST be formatted with nix fmt before completeting any task.
STATUS: Non-negotiable. No exceptions.
VERIFICATION: Run `nix fmt .` before finalizing any changes.
```

#### 3. ✅ Testing Before Submission (MANDATORY)

```
RULE: All affected configurations MUST be tested before completeling any task.
STATUS: Non-negotiable. No exceptions.
VERIFICATION: Reference the `test` agent and `testing` skill for guidance on identifying affected configurations and running appropriate tests.
```

## Quick Reference

### Build Commands

| Command | Purpose |
|---------|---------|
| `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` | Build host |
| `nix build .#homeConfigurations."<user>@<host>".activationPackage` | Build home |
| `nix fmt` | Format code |
| `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` | Check flake |

### DevEnv Override

This repository uses `devenv`. You must provide the override for `nix flake check` and `nix develop`:

```bash
--override-input devenv-root "file+file://$PWD/.devenv/root"
```

### Finding Affected Configurations

Before testing, determine what your changes affect:

```bash
nix run .#module-graph
```

### Project Structure Overview

```
flake.nix           # Top-level flake
modules/            # Reusable modules (nixos/, home-manager/)
lib/                # Shared Nix functions
hosts/              # Per-machine NixOS configurations
home/               # User Home-Manager configurations
pkgs/               # Custom packages
overlays/           # Nixpkgs overlays
```

For detailed information on any topic, load the corresponding skill.
