# Hyprland — Agent Notes

Domain notes for the Hyprland configuration in this repo.
The main subject is the custom Lua layout (`lua:split-tree`), the rest covers the wiring an agent needs to change it safely.

The layout spans several areas — read the map before editing.

## Where things live

| Path                                                          | What                                                              |
| ------------------------------------------------------------- | ----------------------------------------------------------------- |
| `home/shared/desktop/hyprland/`                               | Shared Nix module: base Hyprland options, NVIDIA tweaks           |
| `home/racci/features/desktop/hyprland/`                       | Per-user config: Lua modules, looks, the split-tree layout, tests |
| `home/racci/features/desktop/hyprland/lua/layout/split-tree/` | The layout                                                        |
| `home/racci/features/desktop/hyprland/lua/default.lua`        | Layout entry point: `register`, `configure`, overlay launch       |
| `home/racci/features/desktop/hyprland/tests/split-tree.lua`   | Test harness (no framework)                                       |
| `modules/home-manager/core/hyprland/lua.nix`                  | Nix wiring + `@PLACEHOLDER@` substitution                         |
| `modules/home-manager/core/hyprland/lua/binds.lua`            | Keybinds                                                          |
| `modules/home-manager/core/hyprland/lua/opt/`                 | Optional Lua snippets                                             |
| `pkgs/split-tree-overlay/`                                    | Rust overlay client for the drag preview                          |
| `docs/src/modules/home-manager/hyprland-split-tree.md`        | Layout documentation (keep in sync)                               |

## Environment

- Layout is selected with `general:layout = "lua:split-tree"`. `lua/default.lua` also sets `resize_on_border = true`, `debug.disable_logs = true`, plus snapping and tearing options.

## The custom layout

### One module instance (critical)

- Import with the dotted form everywhere: `require("layout.split-tree")`.
- A path-based require (`./layout/split-tree`) loads a **second** instance with its own `layouts` store.
- `hl.layout.register` must run at config load (`lua/default.lua`), never from a bind.

### State model

- `layouts[workspaceKey] = { root, boxes, area, lastActiveId }`; the key is `tostring(workspace.id)` — never the workspace name, since two workspaces can share one.
- Node: `{ kind = "split", axis = "x"|"y", ratio, first, second, box }` or `{ kind = "leaf", id, box }`, where `id` is `tostring(window.stable_id)`.
- `target:place(box)` is the only geometry application; `recalculate` recomputes boxes from ratios and places them. A wrong tree moves every window.

### Placement and gaps

Hyprland draws the window inset inside the placed tile:

- `general:border_size` on sides on the workspace-area boundary,
- `general:border_size + general:gaps_in` on interior sides.

`layout.contentBox(state, id)` reproduces this. The border-grab hit test needs it to line up with where Hyprland shows the resize cursor.

### Reconciliation across partial recalculates

A reload re-registers the provider and Hyprland re-adds the workspace's targets **one at a time**, running `recalculate` after each.
A recalculate with a subset must not drop the missing leaves — it would rebuild the tree at default ratios and resize windows.

Rule: keep a leaf whose window is still mapped and tiled on the same workspace (temporarily detached); prune only windows that are genuinely gone, moved away, or floated.
Closes and moves are pruned explicitly from `window.close` / `window.move_to_workspace`, which fire before the target is removed.

Closing a **fullscreen** window is the exception that needs a tombstone: the fullscreen-exit recalculate runs before the target is removed, so that pass lists the dying window and would re-tile it.
`window.close` marshals such ids into the layout (`markClosing`), which skips them while they are still listed. See `docs/src/modules/home-manager/hyprland-split-tree.md#closing-a-fullscreen-window`.

### Persistence

- Tree is saved to `$XDG_RUNTIME_DIR/split-tree-layout-<HYPRLAND_INSTANCE_SIGNATURE>.lua` and restored at load, so a reload reproduces the existing geometry.
- Flushed on a 500ms throttle, only when the tree changed.
- No `XDG_RUNTIME_DIR` -> persistence disabled; never fall back to `/tmp`.
- Hyprland embeds **standard Lua 5.5** (not LuaJIT): `load(text, name, "t", {})`, `read("a")`. No 5.1/5.2 shims.

## Pointer input

Native tiled operations do not understand the tree, so all tiled mouse interaction goes through the layout even though Hyprland has `resize_on_border`.

Binds (`modules/home-manager/core/hyprland/lua/binds.lua`):

- `SUPER + mouse:left` (press/release) → `beginMouseDrag` / `endMouseDrag`
- `SUPER + mouse:right` → `beginMouseResize` / `endMouseResize`
- plain `mouse:left` → `beginBorderResize` / `endBorderResize` (`auto_consuming`)
- End binds set `ignore_mods` + `auto_consuming`. Hyprland requires the mods to still match at release, so releasing SUPER first would otherwise leave the session stuck;
  the handlers only consume their own session so plain clicks still pass through.

Resize:

- Resizes the divider actually on the grabbed edge (`findEdgeEntry`). Outer/workspace edges are no-ops, and dead border clicks are consumed so `resize_on_border` cannot move the wrong edge.
- Corner grabs resize both axes; poll is 8ms, dispatch at ≥2px; move threshold is 20px.
- Animations are suppressed for tiled windows during the drag via a temporary `no_anim` window rule matching `float = false`.

Border grab zone:

- within `extend_border_grab_area + border_size` outside the content box, or a clipped rounded corner; never over a window body.
- In a shared gap the nearer window wins; either choice resizes the same divider.
- Skip when a fullscreen/maximized window covers the workspace.
- Resolve the workspace under the cursor, preferring `monitor.active_special_workspace` — a shown special workspace must win, or focus hides it.

Drag reorder:

- Not native drag. The layout freezes the tree, writes a handoff; the overlay previews; on release the layout dispatches a `layout_msg`.
- Handoff (drop map + source box + style) is written to `$XDG_RUNTIME_DIR/split-tree-overlay-<SIG>.json`.
- `visibleStates` is one visible workspace per monitor (`active_special_workspace or active_workspace`), so the cursor can drop onto another monitor or an empty workspace.

### `layout_msg` grammar

`move <dir> [id]`, `insert <movingId> <targetId> <dir>`, `resize <dir> [id]`, `resize_px <id> <axis> <px>`, `resize_edge_px <id> <edge> <px>`.

## The Rust overlay (`pkgs/split-tree-overlay`)

- One click-through layer-shell surface per rectangle, painted from shared memory.
- Watches the handoff with `inotify`, samples the cursor over Hyprland IPC (`cursorpos`), resolves it to a projected box.
- Single instance via a file lock; on takeover it compares `/proc/<pid>/exe` with `current_exe()` and only sends `SIGTERM` when the binary differs. Same build -> exit no-op.
- Launched from `hl.on("hyprland.start")` and `config.reloaded`.
- Modules: `app`, `handlers`, `overlay`, `model`, `resolve`, `ipc`, `paint`, `instance`, `runner`; benches in `benches/paint.rs`.

## Nix wiring and placeholders

- `modules/home-manager/core/hyprland/lua.nix` copies Lua files into the config dir and substitutes `@NAME@` placeholders from `custom-settings.lua.variables`.
  A `@NAME@` that is not in `variables` fails evaluation.
- `luaModules` are copied and required in `init.lua`; `luaExtras` are copied only (the `lua/layout` subtree lives here).
- The overlay executable path is injected as `splitTreeOverlay` in `home/racci/features/desktop/hyprland/default.nix` and used in `lua/default.lua` as `@splitTreeOverlay@`.
- Template files (`binds.lua` with `@applicationBinds@`, `opt/workspaces.lua` with `@workspaceConfig@`) are not valid Lua until substituted — `luac -p` fails on `@`, which is expected.

## Testing and validation

```bash
nix shell nixpkgs#lua5_5 --command lua home/racci/features/desktop/hyprland/tests/split-tree.lua
nix build --no-link .#split-tree-overlay
nix build --no-link --option eval-cache false .#docs
nix fmt .
```

- The harness must run on Lua ≥5.3
- The harness is hermetic: it points `_G.SPLIT_TREE_STATE_PATH` at a throwaway path so it never reads the live state file.
- Update `docs/src/modules/home-manager/hyprland-split-tree.md` with behaviour changes.

## Live debugging

- `hyprctl -i <HYPRLAND_INSTANCE_SIGNATURE> repl '<lua>'` prints results; `... eval` is silent.
- `lua/default.lua` sets `debug.disable_logs = true`, so Lua errors are **not** in `hyprland.log` — use `repl` / `configerrors`.
- Reach live state via `package.loaded["layout.split-tree"]`, then `debug.getupvalue(...)`.
- Useful commands: `hyprctl clients -j`, `monitors -j`, `binds`, `getoption`, `configerrors`.
- Never inject input, dispatch, or reload the live session without explicit permission.

## Pitfalls

- Two module instances from a require-path mismatch (see above).
- keying state by workspace name (see State model).
- Rebuilding the tree on partial recalculates (see Reconciliation).
- Re-tiling a window that closed while fullscreen (see Reconciliation).
- Hit-testing tiles behind a fullscreen/maximized window.
- Special-workspace pointer interactions: use the workspace under the cursor, not `hl.get_active_workspace()`.
