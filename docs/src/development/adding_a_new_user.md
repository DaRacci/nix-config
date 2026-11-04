# Creating New Users

To add a new user configuration:

## 1. Create User Directory

```bash
mkdir -p home/newuser
```

## 2. Create the Shared User Configuration

Every user directory must contain `hm-config.nix`; the flake only builds a Home-Manager configuration for users that have that file.
It is imported next to `home/shared/global`, which imports every module under `modules/home-manager/`, so a user configuration sets options instead of importing feature directories.

```nix
{ ... }:
{
  core.profile = {
    avatar.path = "/home/newuser/.face";
    wallpaper.directory = "/home/newuser/Pictures/Wallpapers";
  };

  purpose = {
    enable = true;
    development = {
      enable = true;
      vcs.user.email = "newuser@example.com";
    };
  };
}
```

Leave `home.stateVersion` out of the file: it is set once for every user from the `state.version` file at the flake root.

CLI tooling is no longer imported per user.
`programSets.shell` is enabled by default on non-server hosts and supplies the shells, prompt, completions, multiplexer and common tools; set `programSets.shell.enable = false;` to opt out.
See [Shell program set](../modules/home-manager/programs/shell.md) for what the set provides.

## 3. Provide the User's Public Key

`core.profile.identity.publicKey` defaults to `home/{username}/id_ed25519.pub` and asserts that the file exists.
Put the user's OpenSSH public key there, or point the option at another path.

## 4. Optional: Host-Specific Configuration

A file named `home/newuser/{hostname}.nix` is imported automatically when the hostname matches an existing host configuration.
Use it for machine-specific settings; anything shared between hosts belongs in `hm-config.nix`.

## 5. Test User Configuration

```bash
# Build home-manager configuration
home-manager build --flake .#newuser@hostname

# Switch to new configuration
home-manager switch --flake .#newuser@hostname
```
