---
name: users
description: Add and configure new Home-Manager users
---

# Users

## User Directory Structure

Each user has directory in `home/<username>/`:

```text
home/<username>/
  hm-config.nix       # Main Home-Manager entry point
  os-config.nix       # NixOS config for all hosts (optional)
  secrets.yaml        # User-specific secrets (optional)
  id_ed25519.pub      # User SSH public key
  <hostname>.nix      # Host-specific config (optional, one per host)
  features/           # User feature modules (optional)
```

## Creating New User

### 1. Create user directory

```bash
mkdir -p home/newuser
```

### 2. Create host-specific configuration

Create `home/newuser/<hostname>.nix` for each host user will use:

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

### 3. Create `hm-config.nix` (shared config)

```nix
# home/newuser/hm-config.nix
{ ... }:
{
  # Config shared across all hosts
  programs.bash.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
  };
}
```

### 4. Create `os-config.nix` (optional)

For NixOS settings that should apply on all hosts where user exists:

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

System auto-links users to hosts based on file existence:

- If `home/<username>/<hostname>.nix` exists, user is configured on that host
- User `os-config.nix` is applied to host NixOS config
- User Home-Manager config is built as `homeConfigurations."<user>@<host>"`

## User Secrets

Create `home/<username>/secrets.yaml` for user-specific secrets:

```yaml
SSH_PRIVATE_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
```

Update `.sops.yaml` to include user age key for that secrets path.

## Shared User Configurations

Common configs live in `home/shared/`:

| Path                        | Purpose                              |
| --------------------------- | ------------------------------------ |
| `home/shared/global/`       | Applied to all users                 |
| `home/shared/applications/` | App configs like browsers or editors |
| `home/shared/desktop/`      | Desktop environment configs          |
| `home/shared/features/cli/` | CLI tool configs                     |

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
# Build Home-Manager configuration
nix build .#homeConfigurations.newuser.activationPackage

# Or use home-manager directly
home-manager build --flake .#newuser
```

See also: `docs/Creating-Users.md`
