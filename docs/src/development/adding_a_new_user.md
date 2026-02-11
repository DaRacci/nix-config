# Creating New Users

To add a new user configuration:

## 1. Create User Directory

```bash
mkdir -p home/newuser
```

## 2. Create User Configuration Files

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

## 3. Link User to Hosts

The auto-discovery system will automatically link users to hosts if:

- A file `home/{username}/{hostname}.nix` exists
- The hostname matches an existing host configuration

## 4. Test User Configuration

```bash
# Build home-manager configuration
home-manager build --flake .#newuser@hostname

# Switch to new configuration
home-manager switch --flake .#newuser@hostname
```
