# Shell Program Set — Shells, Prompt, Completions and CLI Tools

## Purpose

`programSets.shell` is the single switch for a host's interactive shell environment: the login shells, the prompt, completions, the terminal multiplexer and the common command-line tools.
It replaces the per-user `features/cli` imports that earlier revisions of this repository used, so a user configuration enables one option instead of importing a directory of feature files.

## Entry Point

- **Option and imports**: [`modules/home-manager/programs/shell/default.nix`](../../../../../modules/home-manager/programs/shell/default.nix)
- **Shells**: [`shell.nix`](../../../../../modules/home-manager/programs/shell/shell.nix)
- **Prompt**: [`prompt.nix`](../../../../../modules/home-manager/programs/shell/prompt.nix)
- **Completions**: [`completions.nix`](../../../../../modules/home-manager/programs/shell/completions.nix)
- **Multiplexer**: [`multiplexer.nix`](../../../../../modules/home-manager/programs/shell/multiplexer.nix)
- **Tools**: [`tools.nix`](../../../../../modules/home-manager/programs/shell/tools.nix)
- **File manager configuration**: [`xplr.lua`](../../../../../modules/home-manager/programs/shell/xplr.lua)

## Architecture / Services / Scope

### Enablement

`programSets.shell.enable` defaults to true when the host is not a server.
When no `osConfig` is passed in — a standalone Home-Manager build — it also defaults to true.

Every sub-option defaults from the parent switch, so enabling the set is enough for a normal desktop host:

- `programSets.shell.minimal` strips the shell set back for servers: fish is installed from `fishMinimal` and completion generation is skipped.
- `programSets.shell.enableFish` and `programSets.shell.enableNushell` default to whether that shell is the user's login shell in `osConfig`.
  Without an `osConfig`, both default to true.
- `programSets.shell.multiplexer.enable` defaults to `programSets.shell.enable`.
- `programSets.shell.tools.enable` defaults to true for non-server hosts with the set enabled.
  Its groups — `enableModernReplacements`, `enableNetworkTools`, `enableSystemTools` and `enableTUI` — each default from `tools.enable`.

The module asserts that every child switch is only enabled while its parent is, so a group cannot be turned on for a shell set that is off.

### What the set provides

- **History and navigation** — `atuin` and `zoxide` are enabled with the set, and their data directories are added to `user.persistence`.
- **Fish** — enabled through `enableFish`, with history persisted.
- **Nushell** — enabled through `enableNushell`, with `bash-env` integration for the Home-Manager session variables, a carapace-backed external completer, fish as a fallback completer and zoxide for directory jumps.
- **Prompt** — `starship` is enabled whenever the set is enabled.
- **Completions** — `carapace` is enabled for non-server hosts.
  The Nushell integration is configured by hand rather than by the module, so it is switched off in `completions.nix`.
- **Multiplexer** — `zellij` is enabled with session and viewport serialisation, and Nushell attaches to a session on start when it is not already inside one.
- **Tools** — `helix` is the default editor.
  The modern replacements install `bat`, `fd`, `ripgrep`, `duf`, `dust`, `gping`, `procs`, `sd` and `xh`, and alias `cat`, `grep` and `ping` to their replacements.
  The network and system groups add `doggo`, `ttl`, `inxi`, `iotop-c`, `lsof`, `pciutils`, `sysstat`, `btop` and `fastfetch`, plus `nvtop` when the host has GPU acceleration and `ctop` when it runs containers.
  The TUI group adds `fzf`, `trash-cli` and `xplr`.

### Options

Every switch is declared in `modules/home-manager/programs/shell/`; read the module for the exact default, because each one is derived from the host role or the parent switch rather than being a fixed literal.

## Operational Notes / Assumptions

- Server hosts get no shell set by default.
  A server that wants one enables `programSets.shell.enable` explicitly and usually leaves `minimal` at its default.
- `programSets.shell.tools` puts `helix` on the host even when `purpose.development` is disabled; the editor is configured by the shell set, not by the development purpose.
- Nushell completion behaviour depends on `carapace` and `fish` being installed, which the same set provides.
- Persistence entries are declared by this module, so a host that disables the set stops persisting atuin and zoxide data.

## Related

- [Development — languages, editors and version control](../development.md)
- [Profile](../profile.md)
- [list-ephemeral](list_ephemeral.md)
