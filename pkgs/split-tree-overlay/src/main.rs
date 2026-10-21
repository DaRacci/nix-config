//! `split-tree-overlay` renders the drag-and-drop preview for `lua:split-tree` Hyprland layout.
//!
//! The layout writes a JSON "handoff" describing the active drag with a precomputed drop map.
//! This client watches that file, samples the cursor over Hyprland's IPC command socket at the active monitor's refresh rate,
//! resolves the cursor to a projected box, and paints it on the overlay layer.
//! It also paints a highlight outline around the source window.
//!
//! The surfaces sit on the overlay layer as a passthrough.
//! A file lock enforces a single instance across config reloads.

fn main() {
    split_tree_overlay::run();
}
