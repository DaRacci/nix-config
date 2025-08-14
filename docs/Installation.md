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

#### 3. Configure NixOS-WSL
After starting your NixOS-WSL instance:

```bash
# Clone this repository
sudo git clone https://github.com/DaRacci/nix-config.git /etc/nixos

# Apply the WSL configuration
sudo nixos-rebuild switch --flake /etc/nixos#winix
```

#### 4. WSL-Specific Features

The WSL configuration includes:
- SSH agent relay between Windows and WSL
- Hardware acceleration support for development
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

#### 3. Disk Setup
Follow standard NixOS installation procedures for disk partitioning and filesystem setup as described in the [NixOS manual](https://nixos.org/manual/nixos/stable/index.html#sec-installation).

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
```

## Existing NixOS System Migration

### From Traditional NixOS Configuration

#### 1. Backup Current Configuration
```bash
# Backup current configuration (adjust path if using flakes)
sudo cp -r /etc/nixos /etc/nixos.backup
```

#### 2. Clone This Repository
```bash
# Clone to a working directory
git clone https://github.com/DaRacci/nix-config.git /tmp/nix-config
sudo cp -r /tmp/nix-config/* /etc/nixos/
```

#### 3. Create Host Configuration
```bash
# Create your host directory
sudo mkdir -p /etc/nixos/hosts/{device-type}/{hostname}

# Migrate your hardware configuration
sudo cp /etc/nixos.backup/hardware-configuration.nix /etc/nixos/hosts/{device-type}/{hostname}/hardware.nix

# Create default.nix based on your old configuration
# Edit to follow the new structure
```

#### 4. Test and Apply
```bash
# Test the new configuration
sudo nixos-rebuild build --flake .#{hostname}

# Apply if build succeeds
sudo nixos-rebuild switch --flake .#{hostname}
```


