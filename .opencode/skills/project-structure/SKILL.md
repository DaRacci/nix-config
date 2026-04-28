---
name: project-structure
description: Navigate nix-config repository layout and find files
---

# Project Structure

## Directory Layout

```text
flake.nix           # Top-level flake definitions
flake/
  dev/              # Dev shell, CI scripts, formatting
  ci/               # CI-specific flake and scripts
  home-manager/     # Home-Manager flake module
  nixos/            # NixOS flake module

modules/            # Reusable module fragments
  home-manager/     # Home-Manager modules
  nixos/            # NixOS modules

lib/                # Shared Nix functions and helpers
  builders/         # System and home builders (`mkSystem`, `mkHome`)

overlays/           # Nixpkgs overlays
pkgs/               # Custom packages and package sets

hosts/              # Per-machine NixOS configs
  shared/
    global/         # Applied to all hosts
    optional/       # Optional features like gaming or containers
  desktop/          # Desktop machines
    shared/         # Shared across desktops
    <machine>/      # Machine-specific config
  laptop/           # Laptop machines
    shared/
  server/           # Server machines
    shared/
    <machine>/

home/               # User-specific Home-Manager configs
  shared/           # Shared across users
    global/         # Applied to all users
    applications/   # App configs
    desktop/        # Desktop environment configs
    features/       # Feature modules like CLI
  <user>/           # User-specific configs
    <machine>.nix   # Machine-specific overrides
    os-config.nix   # OS config for all machines
    hm-config.nix   # Home-Manager entry point

docs/               # Project docs
```

## Key Files

| File                               | Purpose                     |
| ---------------------------------- | --------------------------- |
| `flake.nix`                        | Flake inputs and outputs    |
| `flake.lock`                       | Locked input versions       |
| `.sops.yaml`                       | SOPS encryption rules       |
| `state.version`                    | NixOS state version         |
| `lib/builders/mkSystem.nix`        | Host system builder         |
| `lib/builders/home/mkHome.nix`     | Home config builder         |
| `modules/nixos/default.nix`        | NixOS module exports        |
| `modules/home-manager/default.nix` | Home-Manager module exports |
| `pkgs/default.nix`                 | Custom package registry     |
| `overlays/default.nix`             | Overlay definitions         |

## Finding Things

- **Host config**: `hosts/<type>/<hostname>/default.nix`
- **User config**: `home/<username>/hm-config.nix`
- **User on host**: `home/<username>/<hostname>.nix`
- **NixOS module**: `modules/nixos/<category>/<name>.nix`
- **HM module**: `modules/home-manager/<category>/<name>.nix`
- **Custom package**: `pkgs/<package-name>/default.nix`
- **Secrets**: `hosts/<type>/<hostname>/secrets.yaml` or `home/<user>/secrets.yaml`
