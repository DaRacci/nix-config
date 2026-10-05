//! `split-tree-overlay` renders the drag-and-drop preview for `lua:split-tree` Hyprland layout.
//!
//! The layout writes a JSON "handoff" describing the active drag with a precomputed drop map.
//! This client watches that file, samples the cursor over Hyprland's IPC command socket at the active monitor's refresh rate,
//! resolves the cursor to a projected box, and paints it on the overlay layer.
//! It also paints a highlight outline around the source window.
//!
//! The surfaces sit on the overlay layer as a passthrough.
//! A file lock enforces a single instance across config reloads.
//!
//! Module map:
//! - [`runner`]: process bootstrap, event-loop wiring and the run loop.
//! - [`app`]: overlay state and the event-driven update loop.
//! - [`handlers`]: Wayland protocol trait implementations.
//! - [`overlay`]: layer-shell surface lifecycle and drawing.
//! - [`model`]: handoff/monitor wire types.
//! - [`resolve`]: cursor-to-tile hit testing.
//! - [`ipc`]: Hyprland command-socket helpers.
//! - [`paint`]: software rasterisation
//! - [`instance`]: startup, locking and single-instance takeover.

pub mod paint;

mod app;
mod handlers;
mod instance;
mod ipc;
mod model;
mod overlay;
mod resolve;
mod runner;

pub use runner::run;
