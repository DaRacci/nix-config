# Installation Guide

This guide covers various installation scenarios for the nix-config repository.

## Windows Subsystem for Linux (WSL)

### Prerequisites
- Windows 10 version 2004 and higher (Build 19041 and higher) or Windows 11
- WSL 2 enabled
- Administrator access to Windows

### Installation Steps

#### 1. Install WSL 2
```powershell
# Run in PowerShell as Administrator
wsl --install

# If WSL is already installed, ensure you're using WSL 2
wsl --set-default-version 2
```

#### 2. Setup NixOS for WSL
Download and install NixOS-WSL via [NixOS-WSL](https://github.com/nix-community/NixOS-WSL):

```powershell
# Download the latest NixOS-WSL tarball
# Import the NixOS-WSL distribution
wsl --import NixOS .\NixOS\ nixos-wsl.tar.gz --version 2

# Start the NixOS instance
wsl -d NixOS
```

#### 3. Configure WSL Settings
Edit `%USERPROFILE%\.wslconfig` on your Windows system to include the following:

```conf
[wsl2]
kernelCommandLine = cgroup_no_v1=all

# Optional: Increase memory allocation for NixOS
memory=8GB
processors=4

# Optional: Enable nested virtualization
nestedVirtualization=true
```

#### 4. Configure NixOS-WSL
After starting your NixOS-WSL instance:

```bash
# Clone this repository
sudo git clone https://github.com/DaRacci/nix-config.git /etc/nixos

# Apply the WSL configuration (winix host)
sudo nixos-rebuild switch --flake /etc/nixos#winix

# Setup home-manager for your user
home-manager switch --flake /etc/nixos#racci@winix
```

#### 5. WSL-Specific Features

The `winix` configuration includes:
- SSH agent relay between Windows and WSL
- GPU acceleration support (CUDA for development)
- Remote desktop capabilities
- Optimized for headless operation

## Native NixOS Installation

### Prerequisites
- NixOS installation media
- Target hardware
- Network connectivity
- Backup of important data

### Installation Process

#### 1. Boot from NixOS Installation Media
- Download NixOS ISO from [nixos.org](https://nixos.org/download.html)
- Create bootable USB/DVD
- Boot from installation media

#### 2. Network Configuration
```bash
# For WiFi connections
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "YourSSID" 
> set_network 0 psk "YourPassword"
> enable_network 0
> quit

# Verify connectivity
ping nixos.org
```

#### 3. Disk Partitioning

##### Option A: Manual Partitioning
```bash
# Example for UEFI systems with single disk
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

##### Option B: Disko (Declarative Disk Setup)
```bash
# Clone the repository first
git clone https://github.com/DaRacci/nix-config.git
cd nix-config

# Use disko configuration (if available for your host)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko hosts/{device-type}/{hostname}/disko.nix
```

#### 4. Generate Hardware Configuration
```bash
# Generate hardware configuration
nixos-generate-config --root /mnt

# Copy to your host configuration
mkdir -p /mnt/etc/nixos/hosts/{device-type}/{hostname}
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/{device-type}/{hostname}/hardware.nix

# Clone this repository
cd /mnt/etc/nixos
git clone https://github.com/DaRacci/nix-config.git .
```

#### 5. Customize Host Configuration
Edit `hosts/{device-type}/{hostname}/default.nix` and `hardware.nix` according to your needs.

#### 6. Install NixOS
```bash
# Install with your specific host configuration
nixos-install --flake .#{hostname}

# Set root password when prompted
```

#### 7. Post-Installation
```bash
# Reboot into new system
reboot

# After reboot, ensure configuration is applied
sudo nixos-rebuild switch --flake /etc/nixos#{hostname}

# Setup home-manager for users
home-manager switch --flake /etc/nixos#username@hostname
```

## Existing NixOS System Migration

### From Traditional NixOS Configuration

#### 1. Backup Current Configuration
```bash
# Backup current configuration
sudo cp -r /etc/nixos /etc/nixos.backup
```

#### 2. Clone This Repository
```bash
# Clone to /etc/nixos
sudo git clone https://github.com/DaRacci/nix-config.git /tmp/nix-config
sudo cp -r /tmp/nix-config/* /etc/nixos/
```

#### 3. Create Host Configuration
```bash
# Create your host directory
sudo mkdir -p /etc/nixos/hosts/{device-type}/{hostname}

# Migrate your hardware configuration
sudo cp /etc/nixos.backup/hardware-configuration.nix /etc/nixos/hosts/{device-type}/{hostname}/hardware.nix

# Create default.nix based on your old configuration.nix
sudo cp /etc/nixos.backup/configuration.nix /etc/nixos/hosts/{device-type}/{hostname}/default.nix
# Edit default.nix to follow the new structure
```

#### 4. Test and Apply
```bash
# Test the new configuration
sudo nixos-rebuild build --flake .#{hostname}

# Apply if build succeeds
sudo nixos-rebuild switch --flake .#{hostname}
```

## Troubleshooting

### Common Issues

#### Build Failures
```bash
# Clear nix store if needed
sudo nix-collect-garbage -d

# Rebuild with verbose output
sudo nixos-rebuild switch --flake .#{hostname} --verbose

# Check for syntax errors
nix flake check
```

#### SSH Issues in WSL
```bash
# Restart SSH agent relay service
systemctl --user restart wsl-ssh-agent-relay
ssh-relay status
```

#### Home Manager Issues
```bash
# Clear home-manager generations
home-manager generations | head -n 5 | awk '{print $7}' | xargs home-manager remove-generations

# Rebuild home configuration
home-manager switch --flake .#username@hostname --verbose
```

#### GPU Acceleration Not Working
1. Ensure host is listed in accelerationHosts in flake.nix
2. Verify drivers are properly configured in hardware.nix
3. Check module imports for CUDA/ROCm support

### Getting Help

- Check [GitHub Issues](https://github.com/DaRacci/nix-config/issues)
- Review NixOS manual: [nixos.org/manual](https://nixos.org/manual/nixos/stable/)
- Join NixOS community: [discourse.nixos.org](https://discourse.nixos.org/)
