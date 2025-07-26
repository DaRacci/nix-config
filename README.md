# Nix Config

This is my interpretation of the perfect nix flake, this powers my desktops, laptops, servers, vms, containers, and all aspects of my computers.

## Features

- **Automated Discovery**: Hosts and users are automatically discovered from filesystem structure
- **Automated Persistence**: TempFS with persistable components using [Impermanence] or BTRFS snapshotting
- **Secret Management**: Encrypted secrets in [NixOS] ([sops-nix]) and [home-manager] ([sops-nix] with [sops])
- **Automated Updates**: Flake dependency updates through Github Actions using [Update-flake-lock]
- **Hardware Acceleration**: Automatic CUDA/ROCm support detection and configuration
- **Modular Architecture**: Custom modules and overlays for extensibility

## Supported Configurations

- [NixOS]-managed systems with automatic configuration discovery:
  - **Desktops**
    - [nixmi] (Personal Desktop with CUDA acceleration)
    - [winix] (WSL 2 instance on Windows for Work with CUDA acceleration)
  - **Servers**
    - [nixai] (Locally hosted AI services)
    - [nixarr] (Media management and automation)
    - [nixcloud] (Replacing usage of external cloud services)
    - [nixdev] (Development environment)
    - [nixio] (Interface between the web & internal services)
    - [nixmon] (Monitoring and observability)
    - [nixserv] (Nix Cache & Build System)

## Repository Structure

The repository uses an **automatic discovery system** that scans the filesystem to build configurations:

```
.
├─ home              # Root for all user homes (auto-discovered)
│  ├─── racci        # User-specific configurations
│  ├─── root         # Root user configurations  
│  └─── shared       # Shared home-manager modules
├─ hosts             # Root for all hosts (auto-discovered by device type)
│  ├─── shared       # Auto-imported modules for all hosts
│  │    ├─── global  # Core system configuration (locale, networking, etc.)
│  │    └─── optional# Optional modules for specific use cases
│  ├─── desktop      # Desktop NixOS systems
│  │    ├─── shared  # Auto-imported modules for desktops
│  │    ├─── nixmi   # Personal desktop with hardware acceleration
│  │    └─── winix   # WSL2 development environment
│  ├─── laptop       # Laptop NixOS Systems  
│  │    └─── shared  # Auto-imported modules for laptops
│  └─── server       # Server NixOS Systems
│       ├─── shared  # Auto-imported modules for servers
│       ├─── nixai   # AI services host
│       ├─── nixarr  # Media automation host
│       ├─── nixcloud# Cloud services replacement
│       ├─── nixdev  # Development services
│       ├─── nixio   # Web interface and proxy
│       ├─── nixmon  # Monitoring stack
│       └─── nixserv # Nix cache and build system
├─ lib               # Extensions to nixpkgs lib and custom builders
│  └─── builders     # System and home-manager configuration builders
├─ modules           # Custom NixOS and home-manager modules
├─ overlays          # NixPkgs overlays for package modifications
├─ pkgs              # Custom packages not in nixpkgs
├─ utils             # Utility scripts for development and debugging
└─ docs              # Additional documentation
```

### Auto-Discovery Mechanism

The flake automatically discovers:
- **Hosts**: By scanning `hosts/{device-type}/` directories (excluding `shared/`)
- **Users**: By scanning `home/` directories and matching with existing hosts
- **Hardware Acceleration**: CUDA/ROCm support based on predefined host lists

## Creating New Hosts

To add a new host to your configuration:

### 1. Create Host Directory Structure
```bash
# For a new desktop host named "mydesktop"
mkdir -p hosts/desktop/mydesktop

# For a new server host named "myserver"  
mkdir -p hosts/server/myserver

# For a new laptop host named "mylaptop"
mkdir -p hosts/laptop/mylaptop
```

### 2. Create Required Configuration Files

Create `hosts/{device-type}/{hostname}/default.nix`:
```nix
{ self, pkgs, ... }:
{
  imports = [
    # Hardware configuration (required)
    ./hardware.nix
    
    # Optional: device-specific modules
    # "${self}/hosts/shared/optional/containers.nix"
    # "${self}/modules/nixos/custom-module.nix"
  ];

  # Host-specific configuration
  host = {
    device.isHeadless = false; # Set to true for servers
  };

  # Add your system configuration here
  # networking.hostName is automatically set from directory name
}
```

Create `hosts/{device-type}/{hostname}/hardware.nix`:
```nix
{ inputs, ... }:
{
  imports = [
    # Include relevant hardware modules
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    
    # For laptops, also include:
    # inputs.nixos-hardware.nixosModules.common-pc-laptop
  ];

  # Boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Filesystem configuration (use disko for declarative disk setup)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Add hardware-specific configuration
}
```

### 3. Add Hardware Acceleration (Optional)

If your host supports CUDA or ROCm, add it to the acceleration lists in `flake.nix`:
```nix
accelerationHosts = {
  cuda = [
    "nixmi"
    "winix"
    "your-new-host"  # Add here for CUDA support
  ];
  rocm = [
    "your-amd-host"  # Add here for ROCm support
  ];
};
```

### 4. Build and Test
```bash
# Build the configuration (don't switch yet)
sudo nixos-rebuild build --flake .#your-new-host

# Test the configuration 
sudo nixos-rebuild test --flake .#your-new-host

# Switch to the new configuration
sudo nixos-rebuild switch --flake .#your-new-host
```

## Creating New Users

To add a new user configuration:

### 1. Create User Directory
```bash
mkdir -p home/newuser
```

### 2. Create User Configuration Files

Create host-specific configurations in `home/newuser/{hostname}.nix`:
```nix
{ pkgs, lib, ... }:
{
  imports = [
    # Import shared configurations
    ./features/cli              # Common CLI tools
    ./features/desktop/common   # Desktop environment basics
  ];

  # User-specific configuration
  home = {
    username = "newuser";
    homeDirectory = "/home/newuser";
    stateVersion = "25.05";
  };

  # Add user-specific packages and configuration
  programs = {
    git = {
      userName = "Your Name";
      userEmail = "your.email@domain.com";
    };
  };
}
```

Create feature modules in `home/newuser/features/`:
```bash
mkdir -p home/newuser/features/{cli,desktop,development}
```

### 3. Link User to Hosts

The auto-discovery system will automatically link users to hosts if:
- A file `home/{username}/{hostname}.nix` exists
- The hostname matches an existing host configuration

### 4. Test User Configuration
```bash
# Build home-manager configuration
home-manager build --flake .#newuser@hostname

# Switch to new configuration  
home-manager switch --flake .#newuser@hostname
```

## Bootstrapping a New System

### Prerequisites
- NixOS installer ISO or existing NixOS system
- Git access to this repository
- Network connectivity

### Installation Process

#### 1. Prepare Installation Media
```bash
# Download NixOS ISO and create bootable media
# Boot from the installation media
```

#### 2. Partition and Format Disks
```bash
# Use disko for declarative disk setup (recommended)
# Or manually partition using standard tools

# Example manual partitioning:
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart root ext4 512MB -8GB
parted /dev/sda -- mkpart swap linux-swap -8GB 100%
parted /dev/sda -- mkpart ESP fat32 1MB 512MB
parted /dev/sda -- set 3 esp on

# Format partitions
mkfs.ext4 -L nixos /dev/sda1
mkswap -L swap /dev/sda2
mkfs.fat -F 32 -n boot /dev/sda3

# Mount filesystems
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
swapon /dev/sda2
```

#### 3. Generate Hardware Configuration
```bash
# Generate initial hardware configuration
nixos-generate-config --root /mnt

# Copy the generated hardware configuration to your host directory
cp /mnt/etc/nixos/hardware-configuration.nix hosts/{device-type}/{hostname}/hardware.nix
```

#### 4. Clone Repository and Configure
```bash
# Clone this repository
cd /mnt
git clone https://github.com/DaRacci/nix-config.git /mnt/etc/nixos

# Edit the hardware configuration as needed
# Ensure your host directory structure is correct
```

#### 5. Install NixOS
```bash
# Install with your flake configuration
nixos-install --flake /mnt/etc/nixos#your-hostname

# Set root password
nixos-install --root /mnt
# Follow prompts to set root password
```

#### 6. Post-Installation Setup
```bash
# Reboot into the new system
reboot

# After reboot, setup users and home-manager
# Clone the repository to a persistent location
sudo git clone https://github.com/DaRacci/nix-config.git /etc/nixos

# Rebuild to ensure everything is working
sudo nixos-rebuild switch --flake /etc/nixos#your-hostname

# Setup home-manager for your user
home-manager switch --flake /etc/nixos#username@hostname
```

### WSL Installation

For WSL systems, follow the [WSL documentation](./docs/Installation.md) which covers:
1. WSL 2 installation
2. NixOS-WSL setup  
3. Required `.wslconfig` configuration
4. WSL-specific configurations

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
[nixai]: ./hosts/server/nixai/
[nixarr]: ./hosts/server/nixarr/
[nixcloud]: ./hosts/server/nixcloud/
[nixdev]: ./hosts/server/nixdev/
[nixio]: ./hosts/server/nixio/
[nixmi]: ./hosts/desktop/nixmi/
[nixmon]: ./hosts/server/nixmon/
[nixos]: https://nixos.org/
[nixserv]: ./hosts/server/nixserv/
[sops]: https://github.com/mozilla/sops
[sops-nix]: https://github.com/Mic92/sops-nix
[update-flake-lock]: https://github.com/DeterminateSystems/update-flake-lock
[winix]: ./hosts/desktop/winix/
