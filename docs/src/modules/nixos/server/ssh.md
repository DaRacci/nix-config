# Server SSH Module

The Server SSH module provides a rich interactive environment for root users upon login. It automatically transitions interactive root sessions into a dedicated development shell, ensuring consistent tooling and a powerful shell experience across server environments.

## Purpose

The SSH submodule enhances administrative access by providing a session-only environment tailored for server management. It removes the need for manual setup of common tools and aliases by automatically entering a pre-configured `nix-shell` when a root user logs in interactively over SSH.

## Options

{{#include ../../../../generated/server-ssh-shell-options.md}}

### Auto-entry Logic (`ssh-shell/default.nix`)

The module creates an indirect GC root for the SSH shell at login time by instantiating shell expression to derivation, then realizing it with `nix-store --add-root --indirect --realise`. This keeps realized shell alive across upgrades without referencing `config.system.build.toplevel` during system evaluation.

The module modifies `/etc/bashrc` to detect interactive root logins via SSH. It evaluates several conditions before launching the session shell:

- User must be root (`EUID=0`).
- Session must be via SSH (`SSH_CONNECTION` present).
- Session must be interactive (`stdin` is a TTY).
- No active session shell detected (`SSH_NIX_SHELL` unset).
- User has not opted out via `NIX_SKIP_SHELL`.

The module also configures OpenSSH to accept the `NIX_SKIP_SHELL` and `SSH_NIX_COMMAND` environment variables from clients, allowing remote users to bypass the auto-shell entry or execute one-shot commands within the shell environment.

### Session Environment (`ssh-shell/shell.nix`)

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

### One-Shot Command Execution (`SSH_NIX_COMMAND`)

The `SSH_NIX_COMMAND` environment variable allows executing a command inside the nix-shell/Fish environment and exiting immediately, rather than starting an interactive session. This is useful for automated verification, remote administration scripts, or one-shot diagnostics.

To use it, forward the variable over SSH and set it to the command you want to run:

```bash
# Per-host in ~/.ssh/config:
# Host myserver
#   SendEnv SSH_NIX_COMMAND

# Or inline:
SSH_NIX_COMMAND="uptime; systemctl status nginx --no-pager" ssh -o SendEnv=SSH_NIX_COMMAND root@server
```

When `SSH_NIX_COMMAND` is set:

1. The normal auto-entry logic runs (bashrc guard, nix-shell instantiation).
1. Inside `shellHook`, the command is executed via `fish -c` after sourcing the Fish initialization.
1. Fish exits with the command's exit status, which propagates back through nix-shell.
1. The SSH session closes immediately after the command completes.

If `SSH_NIX_COMMAND` is unset (or empty), behavior is unchanged — an interactive Fish session starts as normal.

### Opt-Out Behavior

If you need to log in as root without entering the specialized shell, set the `NIX_SKIP_SHELL` environment variable on your local machine before connecting:

```bash
NIX_SKIP_SHELL=1 ssh root@your-server
```

This bypasses the shell entirely, falling straight through to the default system shell. `NIX_SKIP_SHELL` takes precedence over `SSH_NIX_COMMAND`.

### Guard Mechanism

The auto-entry script uses the `SSH_NIX_SHELL` environment variable to prevent recursive shell entries. It runs `nix-shell --add-root --indirect` to build and enter the environment in a single call (pinning a GC root under `/nix/var/nix/gcroots/per-user/root/ssh-shell-result`), which triggers the `shellHook` and exec's Fish. If that fails, the system falls back to the default shell, clears the guard, and prints a message to stderr.

## References

- [OpenSSH Manual](https://www.openssh.com/manual.html)
- [Nix-shell Documentation](https://nixos.org/manual/nix/stable/command-ref/nix-shell.html)
