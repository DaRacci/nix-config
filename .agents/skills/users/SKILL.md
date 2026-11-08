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
{ ... }:
{
  # Host-specific settings only; shared config belongs in hm-config.nix.
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
  core.profile = {
    avatar.path = "/home/newuser/.face";
    wallpaper.directory = "/home/newuser/Pictures/Wallpapers";
  };

  purpose = {
    enable = true;
    development.enable = true;
  };
}
```

`home.stateVersion` comes from the flake root's `state.version`; do not set it
per user.

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
- User Home-Manager config is built as `homeConfigurations.<user>`
  (one per user with `hm-config.nix`)

Standalone `homeConfigurations.<user>` builds do not have a hostname, so
`home/<username>/<hostname>.nix` only applies through host integration.

## User Secrets

Create `home/<username>/secrets.yaml` for user-specific secrets:

```yaml
SSH_PRIVATE_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
```

Add the user's age key to `.sops.yaml`, or run
`./flake/dev/scripts/update-sops.nu` to regenerate it from repo layout.

## Shared User Configurations

Common configs live in `home/shared/`:

| Path                        | Purpose                              |
| --------------------------- | ------------------------------------ |
| `home/shared/global/`       | Applied to all users                 |
| `home/shared/applications/` | App configs like browsers or editors |
| `home/shared/desktop/`      | Desktop environment configs          |
| `home/shared/features/`     | Opt-in features (`games`, `windows`) |

Prefer enabling options in `hm-config.nix`; `home/shared/global` imports every
module under `modules/home-manager/`. Import a shared file only when the config
is not exposed as an option.

## Testing User Configuration

```bash
# Build Home-Manager configuration
nix build .#homeConfigurations.newuser.activationPackage

# Or use home-manager directly
home-manager build --flake .#newuser
```

See also: `docs/src/development/adding_a_new_user.md`
