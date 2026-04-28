---
name: hosts
description: Add and configure new NixOS host machines
---

# Hosts

## Required Files

Each host needs these files in `hosts/<type>/<hostname>/`:

| File | Required | Purpose |
|------|----------|---------|
| `default.nix` | Yes | Main config entry point |
| `secrets.yaml` | Yes | SOPS-encrypted secrets like SSH key and passwords |
| `ssh_host_ed25519_key.pub` | Yes | SSH public key for sops age encryption |
| `hardware.nix` | For physical | Hardware-specific config for desktops and laptops |

## Using Helper Script

Easiest way to create new host:

```bash
# Usage: new-host.sh <host-type> <host-name>
nix run .#new-host -- server mynewserver
nix run .#new-host -- desktop mynewdesktop
```

This script:

1. Creates host directory
2. Generates SSH keypair
3. Creates minimal `default.nix`
4. Updates `.sops.yaml` with new host age key
5. Creates encrypted `secrets.yaml`

## Manual Host Creation

### 1. Create directory structure

```bash
mkdir -p hosts/server/myserver
```

### 2. Create `default.nix`

```nix
# hosts/server/myserver/default.nix
{ modulesPath, ... }:
{
  imports = [
    # For LXC containers:
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    # Or for physical machines:
    # ./hardware.nix
  ];

  host.device.isHeadless = true;  # For servers

  # Host-specific configuration
}
```

### 3. Create `hardware.nix` for physical machines

```nix
# hosts/desktop/mydesktop/hardware.nix
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
```

### 4. Generate SSH key and set up secrets

```bash
# Generate key
ssh-keygen -t ed25519 -f /tmp/ssh_host_ed25519_key -N ""
cp /tmp/ssh_host_ed25519_key.pub hosts/server/myserver/

# Get age key from SSH key
ssh-to-age < hosts/server/myserver/ssh_host_ed25519_key.pub
# Add this to .sops.yaml

# Create secrets file
sops hosts/server/myserver/secrets.yaml
# Add: SSH_PRIVATE_KEY: <content of private key>
```

## Auto-Discovery

Hosts are auto-discovered. No manual flake registration needed. System:

1. Scans `hosts/` for subdirectories
2. Filters out `shared/` and `secrets.yaml`
3. Registers each as `nixosConfiguration`

## Device Types

| Type | Location | Characteristics |
|------|----------|-----------------|
| `server` | `hosts/server/` | Usually headless, often LXC |
| `desktop` | `hosts/desktop/` | GUI, physical hardware |
| `laptop` | `hosts/laptop/` | GUI, battery, physical hardware |

## Shared Configurations

Configurations apply in this order:

1. `hosts/shared/global/` - all hosts
2. `hosts/<type>/shared/` - all hosts of that type
3. `hosts/<type>/<hostname>/` - specific host

## Hardware Acceleration

For CUDA or ROCm support, add host to `flake/nixos/flake-module.nix`:

```nix
accelerationHosts = {
  cuda = [ "nixmi" "mynewhost" ];
  rocm = [ "myamdhost" ];
};
```

## Binding Users to Hosts

Create `home/<username>/<hostname>.nix` to bind user to host. System auto-detects this file and includes user Home-Manager configuration.

See also: `docs/Creating-Hosts.md`
