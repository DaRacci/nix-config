# Server SSH — Root Login Development Shell

## Purpose

The SSH submodule enhances administrative access by providing a session-only environment tailored for server management. It automatically transitions interactive root SSH sessions into a dedicated development shell, ensuring consistent tooling and a powerful shell experience across server environments, and removes the need for manual setup of common tools and aliases.

## Entry Point

- **Main file**: `modules/nixos/server/ssh-shell/default.nix`
- **Supporting file**: `modules/nixos/server/ssh-shell/shell.nix`

#### Options

{{#include ../../../../generated/server-ssh-shell-options.md}}

## Architecture / Services / Scope

The module consists of two parts:

### Auto-entry Logic (`ssh-shell/default.nix`)

- Creates an indirect GC root for the SSH shell at login time by instantiating the shell expression to a derivation, then realizing it with `nix-store --add-root --indirect --realise`. This keeps the realized shell alive across upgrades without referencing `config.system.build.toplevel` during system evaluation.
- Modifies `/etc/bashrc` to detect interactive root logins via SSH. It evaluates several conditions before launching the session shell:
  - User must be root (`EUID=0`).
  - Session must be via SSH (`SSH_CONNECTION` present).
  - Session must be interactive (`stdin` is a TTY).
  - No active session shell detected (`SSH_NIX_SHELL` unset).
  - User has not opted out via `NIX_SKIP_SHELL`.
- Configures OpenSSH to accept the `NIX_SKIP_SHELL` environment variable from clients, allowing remote users to bypass the auto-shell entry when necessary.

### Session Environment (`ssh-shell/shell.nix`)

- The default session shell is a `nix-shell` environment containing:
  - **Modern Shells**: Fish shell with Starship prompt, Zoxide navigation, and Carapace completions.
  - **Enhanced Tooling**: Replacements for standard utilities such as `bat` (cat), `fd` (find), `ripgrep` (grep), and `procs` (ps).
  - **System Diagnostics**: Tools like `btop`, `doggo`, `gping`, `inxi`, and `hyfetch`.
- The `shellHook` in `shell.nix` starts an interactive Fish session and immediately exits the `nix-shell` wrapper once the Fish session concludes.

## Operational Notes / Assumptions

### Opt-Out Behavior

Set the `NIX_SKIP_SHELL` environment variable on your local machine before connecting to log in as root without entering the specialized shell:

```bash
NIX_SKIP_SHELL=1 ssh root@your-server
```

This is particularly useful for automated scripts or troubleshooting scenarios where the standard Bash environment is preferred.

### Guard Mechanism

The auto-entry script uses the `SSH_NIX_SHELL` environment variable to prevent recursive shell entries. It runs `nix-shell --add-root --indirect` to build and enter the environment in a single call (pinning a GC root under `/nix/var/nix/gcroots/per-user/root/ssh-shell-result`), which triggers the `shellHook` and exec's Fish. If that fails, the system falls back to the default shell, clears the guard, and prints a message to stderr.

## References

- [OpenSSH Manual](https://www.openssh.com/manual.html)
- [Nix-shell Documentation](https://nixos.org/manual/nix/stable/command-ref/nix-shell.html)
