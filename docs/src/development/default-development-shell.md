# Default Development Shell

The default `devenv` shell in this repository includes common CLI, Nix, and setup tools used across day-to-day development.

## Entering the Shell

Automatic shell entry via `direnv`, to enable this, run:

```bash
direnv allow
```

Or directly with `nix`:

```bash
nix develop --override-input devenv-root file+file://<path-to-nix-config>/.devenv/root
```

## Generated `.luarc.json`

Entering the default shell refreshes `.luarc.json` in the repository root.

The shell task manages the `"workspace.library"` key by:

- creating `.luarc.json` when missing
- ensuring the current Hyprland stub path is present
- removing stale entries containing `share/hypr/stubs/`
- respect and preserve any other existing keys in `.luarc.json` that are not managed by the shell task.
