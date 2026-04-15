# Home-Manager: list-ephemeral

`list-ephemeral` is a shell utility that helps discover ephemeral paths and generate Nix snippets for persistence. It integrates with Home-Manager to supply defaults, persisted paths, and program context.

## Options

```
programs.list-ephemeral.enable
```

Enable the list-ephemeral integration and generate the runtime config at:

```
$XDG_CONFIG_HOME/list-ephemeral/config.json
```

```
programs.list-ephemeral.extraExcludes
```

Additional exclude patterns for the fd scan.

```
programs.list-ephemeral.extraIncludes
```

Additional paths to always include as candidates. Relative paths are treated as relative to `$HOME`.

## Usage

Default TUI (fzf-based with keybindings):

```
list-ephemeral
```

### TUI Keybindings

| Key | Action |
|-----|--------|
| `/` | Enable search mode (type to fuzzy filter) |
| `Escape` | Disable search and clear query |
| `Ctrl-P` | Open program filter (gum picker) |
| `Ctrl-X` | Clear program filter |
| `Space` | Toggle selection and move down |
| `Ctrl-A` | Select all |
| `Ctrl-D` | Deselect all |
| `Ctrl-C` | Quit (standard fzf behavior) |
| `Enter` | Confirm selection |

**Note:** In browse mode (default), typing text will appear in the prompt but won't filter results. Press `/` to enable search filtering.

List mode:

```
list-ephemeral list
```

Trace mode (runs a command and then opens TUI with traced ephemeral paths):

```
list-ephemeral trace -- <cmd> [args...]
```

## Snippet Generation

The TUI generates Nix snippets based on path location:

- Paths under `$HOME` are emitted as `user.persistence.files` or `user.persistence.directories` with paths relative to `$HOME`.
- Paths outside `$HOME` are emitted as `host.persistence.files` or `host.persistence.directories` with absolute paths.

If the selection includes both kinds, the snippet contains both blocks.
