# Server SSH Module

The Server SSH module provides a rich interactive environment for root users upon login. It automatically transitions interactive root sessions into a dedicated development shell, ensuring consistent tooling and a powerful shell experience across server environments.

## Purpose

The SSH submodule enhances administrative access by providing a session-only environment tailored for server management. It removes the need for manual setup of common tools and aliases by automatically entering a pre-configured `nix-shell` when a root user logs in interactively over SSH.

## Key Options and Behaviors

### Auto-entry Logic (`ssh/default.nix`)

The module modifies `/etc/bashrc` to detect interactive root logins via SSH. It evaluates several conditions before launching the session shell:

- User must be root (`EUID=0`).
- Session must be via SSH (`SSH_CONNECTION` present).
- Session must be interactive (`stdin` is a TTY).
- No active session shell detected (`SSH_NIX_SHELL` unset).
- User has not opted out via `NIX_SKIP_SHELL`.

The module also configures OpenSSH to accept the `NIX_SKIP_SHELL` environment variable from clients, allowing remote users to bypass the auto-shell entry when necessary.

### Session Environment (`ssh/shell.nix`)

The default session shell is a `nix-shell` environment containing:

- **Modern Shells**: Fish shell with Starship prompt, Zoxide navigation, and Carapace completions.
- **Enhanced Tooling**: Replacements for standard utilities such as `bat` (cat), `fd` (find), `ripgrep` (grep), and `procs` (ps).
- **System Diagnostics**: Tools like `btop`, `doggo`, `gping`, `inxi`, and `hyfetch`.

The `shellHook` in `shell.nix` starts an interactive Fish session and immediately exits the `nix-shell` wrapper once the Fish session concludes.

## Per-Module Examples

### Enabling the SSH Shell

Enable the auto-shell behavior in your host configuration:

```nix
{
  server.sshShell.enable = true;
}
```

### Customizing the Shell File

Override the shell definition file if you require a different set of tools:

```nix
{
  server.sshShell.shellFile = ./my-custom-shell.nix;
}
```

## Operational Notes

### Opt-Out Behavior

If you need to log in as root without entering the specialized shell, set the `NIX_SKIP_SHELL` environment variable on your local machine before connecting:

```bash
NIX_SKIP_SHELL=1 ssh root@your-server
```

This is particularly useful for automated scripts or troubleshooting scenarios where the standard Bash environment is preferred.

### Guard Mechanism

The auto-entry script uses the `SSH_NIX_SHELL` environment variable to prevent recursive shell entries. If `nix-shell` fails to start, the system falls back to the default shell and provides a warning message.

## References

- [OpenSSH Manual](https://www.openssh.com/manual.html)
- [Nix-shell Documentation](https://nixos.org/manual/nix/stable/command-ref/nix-shell.html)
