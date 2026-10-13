# Hyprland Split-Tree Layout

## Purpose

Custom Lua layout that implements a split-tree layout for Hyprland, inspired by the `hy3` plugin which itself was inspired by i3's split-tree layout.
This is not a faithful port but an opinionated reimplementation that works around Hyprland Lua layout limitations.

## Files

- Loader: [`home/racci/features/desktop/hyprland/lua/default.lua`](../../../../home/racci/features/desktop/hyprland/lua/default.lua)
- Entry module: [`home/racci/features/desktop/hyprland/lua/layout/split-tree/init.lua`](../../../../home/racci/features/desktop/hyprland/lua/layout/split-tree/init.lua)
- Layout logic: [`home/racci/features/desktop/hyprland/lua/layout/split-tree/layout.lua`](../../../../home/racci/features/desktop/hyprland/lua/layout/split-tree/layout.lua)
- Mouse session handling: [`home/racci/features/desktop/hyprland/lua/layout/split-tree/pointer.lua`](../../../../home/racci/features/desktop/hyprland/lua/layout/split-tree/pointer.lua)
- Overlay bridge: [`home/racci/features/desktop/hyprland/lua/layout/split-tree/overlay.lua`](../../../../home/racci/features/desktop/hyprland/lua/layout/split-tree/overlay.lua)
- Reload persistence: [`home/racci/features/desktop/hyprland/lua/layout/split-tree/persist.lua`](../../../../home/racci/features/desktop/hyprland/lua/layout/split-tree/persist.lua)
- Overlay client: [`pkgs/split-tree-overlay`](../../../../pkgs/split-tree-overlay)
- Shared helpers: [`home/racci/features/desktop/hyprland/lua/layout/split-tree/util.lua`](../../../../home/racci/features/desktop/hyprland/lua/layout/split-tree/util.lua)
- Harness: [`home/racci/features/desktop/hyprland/tests/split-tree.lua`](../../../../home/racci/features/desktop/hyprland/tests/split-tree.lua)
- Workspace startup seeding: [`modules/home-manager/core/hyprland/lua/opt/workspaces.lua`](../../../../modules/home-manager/core/hyprland/lua/opt/workspaces.lua)

## Behavior

### Window insertion

New tiled windows split currently active leaf.
Split axis follows current leaf box shape:

- wider than tall → horizontal split (`x`)
- taller than wide → vertical split (`y`)

### Directional move

`move left/right/up/down` does two things depending on geometry:

- if neighbor exists in requested direction, swap leaves
- if neighbor does not exist, pull active leaf to requested workspace edge

That edge-pull avoids broken nested-column reshapes that earlier Lua version produced.

### Directional resize

`resize left/right/up/down` adjusts nearest ancestor split on requested axis.
Arrow direction means split line moves in same visual direction.

### Floating

Toggling a tiled window to floating (`SUPER + SHIFT + SPACE`) keeps its current tiled size and position instead of letting it grow, by explicitly setting the floating geometry to the window's last tiled box.

### Mouse drag reorder

`SUPER + mouse:left` starts a repo-local drag session.
The compositor's native window drag is deliberately not used: it consumes the mouse release and leaves the window floating, which made the drop unreliable.
Instead split-tree opens the session itself: the dragged window **stays tiled and untouched**, and a layer-shell overlay previews the tile it would land in.
Nothing reflows until release, so the geometry underneath never shifts and the overlay does not have to fight window snapping or compositor re-layout.
While the cursor is still over the dragged window the preview stays at its current box; once it crosses into another tile the preview morphs to the projected drop tile.
An outline is drawn around the dragged source window (by the overlay, not by touching window border properties) so it is obvious which window is being moved; the outline only exists while the overlay does.
On release, split-tree measures the cursor movement; if it moved past a small threshold it computes the target tile from the current layout and dispatches the reorder with a layout message. A click that does not move does not reorder.
Because this is not the compositor's drag, the mouse-release keybind fires reliably.

Drop direction uses a **normalized** cursor offset per axis rather than the plain nearest edge.
A plain nearest-edge comparison biases wide (full-width) tiles toward up/down splits because their top/bottom edges are physically closer, which made it hard to insert a side-by-side column split; normalizing makes each axis compete on equal footing.

Hovered-window hit-testing is scoped to the active workspace so stale geometry from hidden workspaces cannot steal pointer interactions.

### Drag preview overlay

The overlay is a small Rust client ([`pkgs/split-tree-overlay`](../../../../pkgs/split-tree-overlay)).
It creates one `wlr-layer-shell` surface per rect on the overlay layer, anchored top-left, with an empty input region so it is click-through and never steals focus or pointer events, and renders rounded, anti-aliased rectangles from a shared-memory buffer.

**Division of work:** the layout owns the tree; the client owns the per-frame preview.

- `layout.lua#buildDropMap` precomputes, for the frozen tree, the projected tile box for every `region|direction` and `root|direction`. The layout writes this "handoff" once per tree change (drag start, and again on every `recalculate` while a drag is active).
- The client watches the handoff file with inotify, samples the cursor over Hyprland's IPC command socket (`cursorpos`), resolves it to a projected box with a smallest-region hit-test plus the same normalized nearest-edge rule, and paints. It never re-implements the layout algorithm.
- On release the layout re-derives the placement itself and applies it, so the final result never depends on the client.

Handoff shape that gets written to `$XDG_RUNTIME_DIR/split-tree-overlay-<HYPRLAND_INSTANCE_SIGNATURE>.json`:

```jsonc
{
  "dragging": true,
  "draggingId": "17",
  "regions":  [ { "id": "1:3",   "box": { "x": 0, "y": 0, "w": 1280, "h": 1440 } } ],
  "roots":    [ { "id": "1:root", "box": { "x": 0, "y": 0, "w": 2560, "h": 1440 } } ],
  "entries":  { "1:3|left": { ... }, "1:root|right": { ... } },
  "source":   { "x": 0, "y": 0, "w": 1280, "h": 1440 },
  "style":    { "fill": "7aa2f733", "border": "7dcfffcc", "border_width": 3, "rounding": 8, "source_border": "bb9af7aa", "source_border_width": 3 }
}
```

Region and root ids are namespaced with the workspace key (`<ws>:<leaf>` / `<ws>:root`). The drop map covers every visible workspace (one active workspace per monitor), so the cursor can resolve to a tile on another monitor, including an **empty** visible workspace (a windowless workspace still exposes its tileable `area`, and dropping there just moves the window over as its only tile).

Projected boxes are inset by half the inner gap (`general.gaps_in`) on interior edges so the preview lines up with real window borders; sides flush with the workspace area (which already excludes outer gaps) are left alone. The preview border uses the Tokyo Night palette and is drawn 25% thicker than `general.border_size` so it stands out; colours are straight (non-premultiplied) and only premultiplied when composited into the shm buffer.

Sample rate targets the active monitor's refresh rate (from IPC `j/monitors`), re-evaluated as the cursor crosses monitors; it falls back to idle when no drag is active. `border_width` and `rounding` are read from the live Hyprland config (`general.border_size`, `decoration.rounding`) so the preview matches real windows.

The client is launched from `hyprland.start` and `config.reloaded`. It enforces a single instance per session with a file lock, so reloads never spawn duplicates, and it drops the preview on `configreloaded` so a reload that cancels a drag leaves nothing stranded.

Cross-workspace drops are supported: the layout resolves on release which visible workspace and tile the cursor is over. A drop in the dragged workspace uses the normal `insert`/`move` layout message; a drop in another visible workspace moves the window there (Hyprland `window.move` to that workspace), focuses it, then issues the `insert`/`move` layout message in the target workspace so it lands beside the hovered tile rather than wherever the move happens to place it.

### Mouse resize

Two tiled resize paths exist:

- `SUPER + mouse:right` — picks the nearest resizable edge or corner of the hovered tiled window, then resizes along the grabbed axis or axes
- plain `mouse:left` on tiled border — auto-consuming border resize fallback; picks the nearest tiled window whose border the cursor is grabbing

The grabbed edge maps to the split whose divider is actually on that edge, not merely the nearest ancestor split on the axis. So grabbing the right edge of a middle column moves the divider to its right (growing it), and an edge with no divider (an outer/workspace edge) is a no-op instead of moving the opposite side. A border-zone click with nothing to resize is consumed so Hyprland's own `resize_on_border` cannot move the wrong edge instead. Corner grabs resize both axes when both grabbed edges are real dividers.

The border grab zone mirrors Hyprland's own hit test: the cursor must sit within `general.extend_border_grab_area` + `general.border_size` **outside a window's content box** (or inside a rounded corner it clips), and must not be over any window body. The content box is the geometry Hyprland actually draws — the tiled region insets by `general.border_size` on workspace-area edges and by `general.border_size + general.gaps_in` on interior split edges — so the zone lines up with where Hyprland shows the resize cursor. In a shared gap both neighbours are candidates and the nearer one wins; because adjacent tiles share the divider, either choice resizes the same split.

While a resize drag is active, animations are suppressed for tiled windows (a temporary `no_anim` window rule matching `float = false`), so the dragged window and every neighbour sharing the moved divider track the cursor without the `windowsMove` animation lag; the poll runs every 8ms and dispatches once the cursor has moved 2px.

Floating windows stay on native compositor behavior for plain border clicks; modified mouse resize still delegates to native Hyprland drag / resize dispatchers. Floating drag hit-testing expands the window box slightly so a click on the decoration just outside the reported geometry still grabs the floating window rather than the tiled window behind it.

### Reloads

A reload recreates the Lua state, so the tree would otherwise be lost and rebuilt with default ratios, resizing every window on the first pass. The tree is saved shortly after changes (throttled to twice a second, and only when it actually changed) to `$XDG_RUNTIME_DIR/split-tree-layout-<HYPRLAND_INSTANCE_SIGNATURE>.lua` and restored at load, so a reload reproduces the existing geometry instead of enforcing default proportions. The file is keyed by the instance signature, so a fresh session starts clean.

Restoring alone is not enough: when a workspace switches layout (which is what happens as a reload re-registers the provider) Hyprland re-adds the layout targets **one at a time**, running `recalculate` after each. A recalculate that only saw a subset used to drop the missing leaves and re-add them at default proportions, destroying the restored tree. Now a leaf whose window is still mapped and tiled on the same workspace is treated as temporarily detached and kept in the tree (no reflow); only leaves whose window is genuinely gone, moved elsewhere, or floated are pruned. Closes and cross-workspace moves are pruned explicitly from `window.close` / `window.move_to_workspace` events, which fire before the target is removed.

## Why custom dispatchers exist

Hyprland Lua layouts only control placement during `recalculate` and optional string-based `layout_msg` commands.
Native tiled compositor operations do not understand repo-local split-tree state.

Because of that, repo must route tiled interactions through custom layout-aware logic for:

- directional move
- directional resize
- tiled mouse drag reorder
- tiled mouse resize

## Known limits vs `hy3`

Lua layout still cannot fully match native plugin integration:

- no compositor-native tiled drag implementation
- no access to internal tiled resize path for custom tree
- no native grouping / tabs / deck semantics
- plain border drag support depends on bind interception, not compositor-owned tiled border-resize path

## Testing

Run harness directly:

```bash
nix shell nixpkgs#lua5_5 --command lua home/racci/features/desktop/hyprland/tests/split-tree.lua
```
