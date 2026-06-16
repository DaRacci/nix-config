# Home-Manager: Hyprland

This page documents the custom Hyprland Home-Manager helper modules at:

- `modules/home-manager/core/hyprland/`

These modules extend `wayland.windowManager.hyprland` with a typed Nix API for binds, submaps, window rules, permissions, and slide-in popups targeting the HM-native Lua configuration format.

The repo default (set in `home/shared/desktop/hyprland/default.nix`) uses `configType = "lua"`.

In Lua mode, direct `settings.*` attr names must be Lua-safe identifiers. Use underscore-style names like `exec_once`, `window_rule`, and `workspace_rule` instead of dashed hyprlang names like `exec-once`.

All `custom-settings.*` entries are rendered as typed Lua config attrsets:

- `custom-settings.bind` entries become `settings.bind` entries with `hl.dsp.*` dispatcher expressions.
- `custom-settings.submaps` entries become top-level `submaps` attrsets.
- `custom-settings.windowrule` entries become `settings.window_rule` entries.
- `custom-settings.permission` entries set `settings.permission` directly.
- `custom-settings.slideIn` entries generate `custom-settings.bind` entries dynamically.

Old dashed forms like `exec-once` stay valid only when passed through unchanged hyprlang/string config, not as direct Lua attr names.

The camelCase custom module API remains consistent in Nix.

---

## Module Files

### `default.nix`

Entry point that imports all sub-modules under `custom-settings`. Also imports `noctalia.nix` which adds Noctalia desktop shell integration (see below).

### `bind.nix`

Defines `custom-settings.bind` and `custom-settings.submaps`.

Attribute set keyed by key combination (e.g. `"SUPER+T"`). Each entry accepts either an action list or a submodule with:

- `keybind` (auto-derived from the attr name)
- `modifiers` — list of flags (`"locked"`, `"release"`, `"repeat"`, `"longPress"`, `"nonConsuming"`, `"transparent"`, `"ignoreMods"`)
- `action` — dispatcher name + args (e.g. `["exec", "kitty"]`)

Short form:

```nix
custom-settings.bind = {
  "SUPER+T" = [ "exec" "kitty" ];
  "SUPER+Q" = [ "killactive" ];
};
```

Submodule form with modifiers:

```nix
custom-settings.bind = {
  "SUPER+SHIFT+Q" = {
    modifiers = [ "repeat" ];
    action = [ "resizeactive" "0 50" ];
  };
};
```

**`custom-settings.submaps`**: Attribute set of submap definitions. Each submap has:

- `enter` — keybind to activate the submap
- `reset` — keybind to return to the default submap (optional)
- `binds` — same format as `custom-settings.bind`

```nix
custom-settings.submaps = {
  resize = {
    enter = "SUPER+R";
    reset = [ "SUPER" "R" ];
    binds = {
      "SUPER+H" = [ "movewindow" "l" ];
      "SUPER+L" = [ "movewindow" "r" ];
      "SUPER+K" = [ "movewindow" "u" ];
      "SUPER+J" = [ "movewindow" "d" ];
    };
  };
};
```

Known dispatchers (`exec`, `submap`, `workspace`, `movetoworkspace`, `togglespecialworkspace`, `resizeactive`, `movefocus`, `movewindow`, `killactive`, `fullscreen`, `togglefloating`) map to `hl.dsp.*` Lua API calls. Unknown or plugin-provided dispatchers fall back to `hl.dsp.exec_cmd("hyprctl dispatch ...")`.

### `windowRule.nix`

Defines `custom-settings.windowrule`: an attribute set of named window rules. Each rule has:

- `name` — rule name (defaults to the attribute key)
- `matcher` — list of match conditions (window class, title, workspace, etc.)
- `rule` — rule properties (float, fullscreen, size, move, opacity, center, monitor, workspace, pin, group, border, animation, idle inhibit, and many more)

```nix
custom-settings.windowrule = {
  "kitty-floating" = {
    matcher = [ { class = "kitty"; } ];
    rule = {
      float = true;
      center = true;
      size = {
        width = "40%";
        height = "60%";
      };
    };
  };

  "firefox-picture-in-picture" = {
    matcher = [
      {
        title = "Picture-in-Picture";
        class = "firefox";
      }
    ];
    rule = {
      pin = true;
      opacity.activeopacity = 0.9;
    };
  };
};
```

Complex matchers and compound rule types (workspace selectors, monitor selectors, fullscreen state, opacity, center with reserved area, max/min size, move) are fully typed in `types.nix`.

### `permission.nix`

Defines `custom-settings.permission` for screen copy and plugin permission grants:

```nix
custom-settings.permission = {
  screenCopy = [ "firefox" "obs" ];
  plugin = [ "hyprscroller" ];
};
```

### `slideIn.nix`

Defines `custom-settings.slideIn` — a list of edge-sliding popup windows. Each entry configures a keybind, executable, window class, position (`left`/`right`/`top`/`bottom`/`edge`/`side`), and optional window rules. Uses `hdrop` for dropdown-style window management.

### `noctalia.nix`

Integrates the [Noctalia](https://github.com/noctaliawm/noctalia) desktop shell as a Hyprland companion. Requires the `noctalia` flake input (added in `flake/home-manager/flake.nix`).

The module:

- Enables `programs.noctalia` and `systemd`, pins `package` from `inputs.noctalia.packages`, and applies a Hyprland layer blur rule for Noctalia windows.
- Mirrors a full exported Noctalia v5 config as a typed Nix attrset (`noctaliaSettings`), covering bar layouts with monitor overrides, shell panel/screen corners/screenshot/session actions, theme (builtin "Noctalia" with community palette "Tokyo Night Moon"), wallpaper (directory, default/last/monitor paths, automation), calendar, control-center shortcuts, desktop/lockscreen widgets, notification layer, plugin settings, widget config, brightness, and more.
- Does **not** declare top-level `colors` or `plugins` HM options, and does **not** manage raw JSON files directly.
- Persists `~/.local/share/noctalia` via `user.persistence.directories`.
- Reads `core.profile.avatar.path` → `shell.avatar_path` and `core.profile.wallpaper.directory` → `wallpaper.directory`. Wallpaper fill mode is hardcoded to `crop` (not a profile option).
- Location driven by `core.profile.location.secret` (SOPS secret name). Two modes:
  - **Normal** (`secret == null`): sets `programs.noctalia.settings` with build-time validation. No location block.
  - **Secret** (`secret != null`): base TOML generated at build time; activation copies it to `~/.config/noctalia/config.toml` and appends `[location] address` from decrypted `sops.secrets.<name>.path`. Clear text never in repo or Nix store.

The user-side Hyprland config (`home/racci/features/desktop/hyprland/`) pairs with this module via Noctalia IPC keybinds:

| Binding                               | Action                                                                 |
| ------------------------------------- | ---------------------------------------------------------------------- |
| `SUPER+SPACE` → `SUPER+SHIFT+F`       | fullscreen (displaced by Noctalia launcher bind)                       |
| `SUPER+S` → `SUPER+grave`             | special workspace toggle (displaced by Noctalia control center bind)   |
| `SUPER+SHIFT+S` → `SUPER+SHIFT+grave` | move window to special workspace (displaced by Noctalia settings bind) |
| `SUPER+comma`                         | Noctalia settings                                                      |
| Audio/brightness keys                 | `noctalia msg ...` dispatchers                                         |

Workspace rules in the user config now set `persistent = true` for defined workspaces, ensuring they are always available regardless of Noctalia lifecycle.

Look settings are tuned toward Noctalia documentation recommendations: `gaps_in = 5`, `gaps_out = 10`, `rounding_power = 2`, shadow range/render/color tuned, and blur size/passes/vibrancy adjusted.

### `types.nix`

Shared type definitions used across the modules:

- `monitorSelector` — typed Nix attrs for monitor matching (by `name` or `index`)
- `workspaceSelector` — typed Nix attrs for workspace matching (by `id`, `relativeId`, `name`, or `special`)
- `rule` — all typed window rule properties (float, fullscreen, opacity, size, move, center, monitor, workspace, and dozens more)
- `windowMatch` — match condition types (class, title, initialClass, initialTitle, tag, xwayland, float, fullscreen, pin, focus, group, modal, fullscreenstate, workspace, content, xdg_tag)

---

## Usage Example

```nix
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    custom-settings = {
      bind = {
        "SUPER+T" = [ "exec" "kitty" ];
        "SUPER+W" = [ "exec" "firefox" ];
        "SUPER+Q" = [ "killactive" ];
      };

      submaps.resize = {
        enter = "SUPER+R";
        reset = [ "SUPER" "R" ];
        binds = {
          "SUPER+H" = [ "movewindow" "l" ];
          "SUPER+L" = [ "movewindow" "r" ];
        };
      };

      windowrule."kitty-floating" = {
        matcher = [ { class = "kitty"; } ];
        rule = {
          float = true;
          size = { width = "40%"; height = "60%"; };
          center = true;
        };
      };

      permission = {
        screenCopy = [ "firefox" ];
      };
    };
  };
}
```

---

## Notes

- All options live under `custom-settings` to avoid collision with upstream HM Hyprland options.
- Unknown dispatchers fall back to `hyprctl dispatch` via `hl.dsp.exec_cmd`.
- CamelCase naming in Nix (e.g. `fullscreenState`, `idleInhibit`, `keepAspectRatio`, `noCloseFor`, `forceRgbx`, `syncFullscreen`) is translated to snake_case in the Lua output.
