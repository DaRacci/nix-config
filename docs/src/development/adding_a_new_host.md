# Creating New Hosts

To add a new host to your configuration:

## 1. Create Host Directory Structure

```bash
# For a new desktop host named "mydesktop"
mkdir -p hosts/desktop/mydesktop

# For a new server host named "myserver"
mkdir -p hosts/server/myserver

# For a new laptop host named "mylaptop"
mkdir -p hosts/laptop/mylaptop
```

## 2. Create Required Configuration Files

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

## 3. Add Hardware Acceleration (Optional)

If your host supports hardware acceleration, add it to the acceleration lists in `flake.nix`:

```nix
accelerationHosts = {
  cuda = [
    "your-new-host"  # Add here for CUDA support
  ];
  rocm = [
    "your-amd-host"  # Add here for ROCm support
  ];
};
```

## 4. Build and Test

```bash
# Build the configuration (don't switch yet)
sudo nixos-rebuild build --flake .#your-new-host

# Test the configuration
sudo nixos-rebuild test --flake .#your-new-host

# Switch to the new configuration
sudo nixos-rebuild switch --flake .#your-new-host
```
