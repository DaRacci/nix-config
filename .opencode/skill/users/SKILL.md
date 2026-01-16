---
name: users
description: Add and configure new Home-Manager users
---

# Users

## User Directory Structure

Each user has a directory in `home/<username>/`:

```
home/<username>/
  hm-config.nix       # Main Home-Manager entry point
  os-config.nix       # NixOS config applied to all hosts (optional)
  secrets.yaml        # User-specific secrets (optional)
  id_ed25519.pub      # User's SSH public key
  <hostname>.nix      # Host-specific config (one per host, optional)
  features/           # User's feature modules (optional)
```

## Creating a New User

### 1. Create user directory

```bash
mkdir -p home/newuser
```

### 2. Create host-specific configuration

Create `home/newuser/<hostname>.nix` for each host the user will use:

```nix
# home/newuser/nixmi.nix
{ pkgs, lib, ... }:
{
  imports = [
    # Import shared configurations
    ../shared/features/cli
    ../shared/desktop/common
  ];

  programs.git = {
    userName = "Your Name";
    userEmail = "your.email@domain.com";
  };
}
```

### 3. Create hm-config.nix (shared config)

```nix
# home/newuser/hm-config.nix
{ ... }:
{
  # Configuration shared across all hosts
  programs.bash.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
  };
}
```

### 4. Create os-config.nix (optional)

For NixOS settings that should apply to all hosts where this user exists:

```nix
# home/newuser/os-config.nix
{ pkgs, ... }:
{
  # This is NixOS config, not Home-Manager
  users.users.newuser = {
    extraGroups = [ "docker" "libvirtd" ];
  };
}
```

## User-Host Binding

The system automatically links users to hosts based on file existence:

- If `home/<username>/<hostname>.nix` exists, that user is configured on that host
- The user's `os-config.nix` is applied to the host's NixOS config
- The user's home-manager config is built as `homeConfigurations."<user>@<host>"`

## User Secrets

Create `home/<username>/secrets.yaml` for user-specific secrets:

```yaml
SSH_PRIVATE_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
```

Update `.sops.yaml` to include the user's age key for their secrets path.

## Shared User Configurations

Common configurations live in `home/shared/`:

| Path | Purpose |
|------|---------|
| `home/shared/global/` | Applied to all users |
| `home/shared/applications/` | Application configs (browsers, editors) |
| `home/shared/desktop/` | Desktop environment configs |
| `home/shared/features/cli/` | CLI tool configurations |

Import these in user configs:

```nix
{
  imports = [
    ../shared/features/cli
    ../shared/applications/browser.nix
  ];
}
```

## Testing User Configuration

```bash
# Build home-manager configuration
nix build .#homeConfigurations.newuser.activationPackage

# Or use home-manager directly
home-manager build --flake .#newuser
```

See also: `docs/Creating-Users.md`
