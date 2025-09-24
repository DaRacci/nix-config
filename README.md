# Nix Config

This is my interpretation of the perfect nix flake, this powers my desktops, laptops, servers, vms, containers, and all aspects of my computers.

## Features

- **Automated Discovery**: Hosts and users are automatically configured from filesystem structure
- **Automated Persistence**: TempFS with persistable components using [Impermanence] or BTRFS snapshotting
- **Secret Management**: Encrypted secrets in [NixOS] ([sops-nix]) and [home-manager] ([sops-nix] with [sops])
- **Automated Updates**: Flake dependency updates through Github Actions using [Update-flake-lock]
- **Hardware Acceleration**: Automatic hardware acceleration support detection and configuration
- **Modular Architecture**: Custom modules and overlays for extensibility

## Supported Configurations

- [NixOS]-managed systems with automatic configuration discovery:
  - **Desktops** - Personal workstations and development environments
  - **Servers** - Infrastructure services and automation
  - **Laptops** - Portable systems with power management

## Repository Structure

The repository uses an **automatic discovery system** that scans the filesystem to build configurations:

```
.
├─ home              # Root for all user homes (auto-discovered)
│  ├─── {username}   # User-specific configurations
│  └─── shared       # Shared home-manager modules
├─ hosts             # Root for all hosts (auto-discovered by device type)
│  ├─── shared       # Auto-imported modules for all hosts
│  │    ├─── global  # Core system configuration (locale, networking, etc.)
│  │    └─── optional# Optional modules for specific use cases
│  ├─── desktop      # Desktop NixOS systems
│  │    ├─── shared  # Auto-imported modules for desktops
│  │    ├─── {host}  # Individual desktop host configurations
│  ├─── laptop       # Laptop NixOS Systems
│  │    ├─── shared  # Auto-imported modules for laptops
│  │    └─── {host}  # Individual laptop host configurations
│  └─── server       # Server NixOS Systems
│       ├─── shared  # Auto-imported modules for servers
│       └─── {host}  # Individual server host configurations
├─ lib               # Extensions to nixpkgs lib and custom builders
│  └─── builders     # System and home-manager configuration builders
├─ modules           # Custom NixOS and home-manager modules
├─ overlays          # NixPkgs overlays for package modifications
├─ pkgs              # Custom packages not in nixpkgs
└─ docs              # Additional documentation
```

### Auto-Discovery Mechanism

The flake automatically discovers:

- **Hosts**: By scanning `hosts/{device-type}/` directories (excluding `shared/`)
- **Users**: By scanning `home/` directories and matching with existing hosts
- **Hardware Acceleration**: Support based on predefined host lists

## Getting Started

- **[Creating New Hosts](./docs/Creating-Hosts.md)** - Step-by-step guide to add new hosts to your configuration
- **[Creating New Users](./docs/Creating-Users.md)** - Instructions for adding new user configurations
- **[Installation Guide](./docs/Installation.md)** - Complete installation and setup instructions

## Things on the TODO

> These probably won't happen honestly

- Cosmic Desktop once stabilized
- Declarative disk management with disko for all hosts
- Automated backup strategies for persistent data

## Development

This repository includes utilities for development and debugging:

- `utils/get-os-imports.nix` - Debug NixOS module imports
- `utils/get-hm-imports.nix` - Debug home-manager imports
- `utils/get-imports.nu` - Nushell script for import analysis

## Links

[home-manager]: https://github.com/nix-community/home-manager
[impermanence]: https://github.com/nix-community/impermanence
[nixos]: https://nixos.org/
[sops]: https://github.com/mozilla/sops
[sops-nix]: https://github.com/Mic92/sops-nix
[update-flake-lock]: https://github.com/DeterminateSystems/update-flake-lock
