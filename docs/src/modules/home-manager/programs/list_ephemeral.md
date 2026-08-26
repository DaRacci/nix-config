# list-ephemeral — Ephemeral Path Discovery and Persistence Snippets

## Purpose

`list-ephemeral` is a shell utility that helps discover ephemeral paths and generate Nix snippets for persistence. It integrates with Home-Manager to supply defaults, persisted paths, and program context.

## Entry Point

- **Main file**: [`modules/home-manager/programs/list-ephemeral.nix`](../../../../../modules/home-manager/programs/list-ephemeral.nix)
- **Package**: [`pkgs/list-ephemeral`](../../../../../pkgs/list-ephemeral)

## Architecture / Services / Scope

##### Options

{{#include ../../../../generated/programs-list-ephemeral-options.md}}

The module writes a generated config file consumed by the TUI:

- Excludes default ephemeral paths (caches, logs, Electron app state, etc.) so they never appear as persistence candidates.
- Supplies the currently persisted files and directories from `user.persistence` / `host.persistence`, which are marked as already persisted in the UI.
- Supplies installed program names so the TUI can filter candidates by program context.

### Usage

Default TUI (fzf-based with keybindings):

```sh
list-ephemeral
```

#### TUI Keybindings

| Key      | Action                                    |
| -------- | ----------------------------------------- |
| `/`      | Enable search mode (type to fuzzy filter) |
| `Escape` | Disable search and clear query            |
| `Ctrl-P` | Open program filter (gum picker)          |
| `Ctrl-X` | Clear program filter                      |
| `Space`  | Toggle selection and move down            |
| `Ctrl-A` | Select all                                |
| `Ctrl-D` | Deselect all                              |
| `Ctrl-C` | Quit (standard fzf behavior)              |
| `Enter`  | Confirm selection                         |

**Note:** In browse mode (default), typing text will appear in the prompt but won't filter results. Press `/` to enable search filtering.

List mode:

```
list-ephemeral list
```

Trace mode (runs a command and then opens TUI with traced ephemeral paths):

```
list-ephemeral trace -- <cmd> [args...]
```

### Snippet Generation

The TUI generates Nix snippets based on path location:

- Paths under `$HOME` are emitted as `user.persistence.files` or `user.persistence.directories` with paths relative to `$HOME`.
- Paths outside `$HOME` are emitted as `host.persistence.files` or `host.persistence.directories` with absolute paths.

If the selection includes both kinds, the snippet contains both blocks.
