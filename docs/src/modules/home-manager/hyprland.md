# Home-Manager: Hyprland

This page documents the custom Hyprland Home-Manager helper modules at:

- `modules/home-manager/core/hyprland/`

These modules extend `wayland.windowManager.hyprland` with a typed Nix API for window rules, permissions, slide-in popups, input defaults, and Lua config generation targeting the HM-native Lua configuration format.

The repo default (set in `home/shared/desktop/hyprland/default.nix`) uses `configType = "lua"`.

In Lua mode, direct `settings.*` attr names must be Lua-safe identifiers. Use underscore-style names like `exec_once`, `window_rule`, and `workspace_rule` instead of dashed hyprlang names like `exec-once`.

The module structure is:

```
default.nix       # Top-level importer (imports all submodules)
├── permission.nix   # custom-settings.permission
├── slideIn.nix      # custom-settings.slideIn
├── windowRule.nix   # custom-settings.windowrule
├── input.nix        # settings.config defaults (cursor, binds, input, misc)
├── lua.nix          # custom-settings.lua (Lua config generation)
│   └── lua/binds.lua  # Default Lua bind template with @placeholder@ substitution
└── types.nix        # Shared type definitions
```

---

## Module Files

### `input.nix`

Sets sensible default values under `settings.config` for cursor behavior, input device settings, keyboard binds, and misc Hyprland options. This module activates automatically when the Hyprland HM module is enabled — no `custom-settings` option is involved. Override any value via `settings.config.input.*` etc.

Default config covers:

- `cursor` — warp behavior, hardware cursors, inactivity timeout, hide-on-key-press
- `binds` — workspace back-and-forth, allow workspace cycles, focus method
- `input` — keyboard layout, follow-mouse, touchpad, sensitivity, accel profile
- `misc` — DPMS on key/mouse events

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
  screenCopy = [ pkgs.firefox pkgs.obs ];
  plugin = [ pkgs.hyprlandPlugins.hy3 ];
};
```

### `slideIn.nix`

Defines `custom-settings.slideIn` — a list of edge-sliding popup windows. Each entry configures a keybind, executable, window class, position (`left`/`right`/`top`/`bottom`/`edge`/`side`), and optional window rules. Uses `hdrop` for dropdown-style window management.

### `lua.nix`

Defines `custom-settings.lua` — the Lua config generation subsystem. Options:

- **`enable`** (boolean, default `false`) — Enable pure Lua configuration files with Nix substitution support.

- **`variables`** (attrs of `nullOr str`, default `{}`) — Key-value pairs for `@placeholder@` substitution in Lua source files. Each key `foo` replaces `@foo@` in all sourced Lua modules with the given value. Some variables are pre-populated automatically (see `applicationBinds` below). Common injected values include paths to `playerctl`, `wpctl`, `zenity`, `hyprshutdown`, and `uwsm-app`.

- **`luaModules`** (list of paths, default `[ ./lua/binds.lua ]`) — Lua source files to copy into the Hyprland config directory and `require` from `init.lua`. Each file undergoes `@placeholder@` substitution using the `variables` attrset. The default list includes `lua/binds.lua`.

- **`applicationBinds`** (attrs of `str`, default `{}`) — Application keybinds passed into Lua generation. Each attr key is bind string (for example `"SUPER+Return"`) and each attr value is command string. Rendered into `@applicationBinds@` as Lua table entries consumed by `binds.lua`:

  ```nix
  custom-settings.lua.applicationBinds = {
    "SUPER + Return" = "${pkgs.kitty}/bin/kitty";
    "SUPER + E" = "${pkgs.nautilus}/bin/nautilus";
  };
  ```

  Generated Lua iterates over those table entries and creates `hl.bind(..., hl.dsp.exec_cmd(...))` calls for each bind/command pair.

#### Lua bind pattern

In `lua/binds.lua`, binds use the inline Lua expression pattern via `settings.bind` with `attrsToLuaInlineArgs`. The generated Lua calls `hl.bind(...)` with first-class dispatcher functions:

```lua
hl.bind("SUPER + Q", hl.dsp.window.kill())
hl.bind("SUPER + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind("ALT + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
  hl.bind("ESCAPE", hl.dsp.submap("reset"))
  -- ...
end)
```

This pattern keeps bind and submap definitions inline in Lua. Submaps are defined via `hl.define_submap(name, fn)` alongside related `hl.bind(...)` calls.

### `lua/binds.lua`

The default Lua bind template at `modules/home-manager/core/hyprland/lua/binds.lua`. Uses `@placeholder@` substitution for dynamic injection:

| Placeholder              | Source                                 | Description                              |
| ------------------------ | -------------------------------------- | ---------------------------------------- |
| `@applicationBinds@`     | `custom-settings.lua.applicationBinds` | Auto-generated Lua table of app keybinds |
| `@playerctl@`            | Auto-injected                          | Path to `playerctl` binary               |
| `@wpctl@`                | Auto-injected                          | Path to `wpctl` binary                   |
| `@zenity@`               | Auto-injected                          | Path to `zenity` binary                  |
| `@hyprshutdown@`         | Auto-injected                          | Path to `hyprshutdown` binary            |
| `@uwsmApp@`              | Auto-injected                          | Path to `uwsm-app` helper                |
| `@DEFAULT_AUDIO_SINK@`   | `custom-settings.lua.variables`        | Audio sink name (default `null`)         |
| `@DEFAULT_AUDIO_SOURCE@` | `custom-settings.lua.variables`        | Audio source name (default `null`)       |

Add `@custom@` placeholders by extending `custom-settings.lua.variables`.

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
      windowrule."kitty-floating" = {
        matcher = [ { class = "kitty"; } ];
        rule = {
          float = true;
          size = { width = "40%"; height = "60%"; };
          center = true;
        };
      };

      permission = {
        screenCopy = [ pkgs.firefox ];
      };

      lua = {
        enable = true;
        applicationBinds = {
          "SUPER + Return" = "${pkgs.kitty}/bin/kitty";
          "SUPER + E" = "${pkgs.nautilus}/bin/nautilus";
        };
      };
    };
  };
}
```

---

## Notes

- All options live under `custom-settings` to avoid collision with upstream HM Hyprland options.
- `lua.nix` auto-injects `applicationBinds`, `playerctl`, `wpctl`, `zenity`, `hyprshutdown`, and `uwsmApp` as substitution variables — no need to set those manually.
- Unknown dispatchers in Lua raises a runtime error from Hyprland's Lua parser, not a build-time error.
- CamelCase naming in Nix (e.g. `fullscreenState`, `idleInhibit`, `keepAspectRatio`, `noCloseFor`, `forceRgbx`, `syncFullscreen`) is translated to snake_case in the Lua output.
