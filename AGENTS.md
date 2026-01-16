# Repository Guidelines for Agents

Quick reference for agents working on this Nix-based configuration repository.
Load skills as needed for detailed guidance on specific tasks.

## Critical Requirements

Items marked with **MUST** are mandatory and must be followed at all times:

- **MUST** run `nix fmt <paths...>` after making any changes
- **MUST** test affected configurations before submitting (see `testing` skill)

## Available Skills

Load these skills as needed using the skill tool:

| Skill | When to Use |
|-------|-------------|
| `project-structure` | Finding files and understanding repository layout |
| `code-style` | Writing or modifying Nix code |
| `building` | Building NixOS or Home-Manager configurations |
| `testing` | Testing changes before submitting |
| `contributing` | Creating commits or pull requests |
| `modules` | Creating or modifying NixOS/Home-Manager modules |
| `hosts` | Adding or configuring host machines |
| `users` | Adding or configuring users |
| `packages` | Creating custom packages |
| `secrets` | Managing encrypted secrets with sops-nix |
| `debugging` | Troubleshooting Nix evaluation and build errors |

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
./flake/dev/scripts/module-graph.nu
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
