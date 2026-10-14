//! Types shared between the Lua handoff payload and the overlay.

use std::collections::HashMap;

use serde::Deserialize;

/// A rectangle in Hyprland's global layout coordinate space.
/// Fractional because drop boxes are projected from tiled ratios rather than whole pixels.
#[derive(Clone, Copy, Default, Deserialize, PartialEq)]
pub(crate) struct Geo {
    pub(crate) x: f64,
    pub(crate) y: f64,
    pub(crate) w: f64,
    pub(crate) h: f64,
}

/// A drop target region (`<ws>:<leaf>` or `<ws>:root`) and the tile box it covers.
#[derive(Clone, Deserialize)]
pub(crate) struct DropRegion {
    #[serde(default)]
    pub(crate) id: String,
    #[serde(default, rename = "box")]
    pub(crate) geometry: Geo,
}

/// Overlay palette and metrics
#[derive(Clone, Deserialize)]
pub(crate) struct Style {
    #[serde(default = "default_fill")]
    pub(crate) fill: String,
    #[serde(default = "default_border")]
    pub(crate) border: String,
    #[serde(default = "default_border_width", rename = "border_width")]
    pub(crate) border_width: i32,
    #[serde(default = "default_rounding")]
    pub(crate) rounding: i32,
    #[serde(default = "default_source_border", rename = "source_border")]
    pub(crate) source_border: String,
    #[serde(default = "default_border_width", rename = "source_border_width")]
    pub(crate) source_border_width: i32,
}

impl Default for Style {
    fn default() -> Self {
        Self {
            fill: default_fill(),
            border: default_border(),
            border_width: default_border_width(),
            rounding: default_rounding(),
            source_border: default_source_border(),
            source_border_width: default_border_width(),
        }
    }
}

fn default_fill() -> String {
    "7aa2f733".to_string()
}

fn default_border() -> String {
    "7dcfffcc".to_string()
}

fn default_source_border() -> String {
    "bb9af7aa".to_string()
}

fn default_border_width() -> i32 {
    2
}

fn default_rounding() -> i32 {
    8
}

/// The JSON payload the Lua layout writes while a drag is active.
///
/// `regions` are the per-window drop zones, `roots` are the per-workspace edge drop zones,
/// and `entries` maps `<region-id>|<direction>` to the projected resulting tile box.
#[derive(Default, Deserialize)]
pub(crate) struct Handoff {
    #[serde(default)]
    pub(crate) dragging: bool,
    #[serde(default)]
    pub(crate) regions: Vec<DropRegion>,
    #[serde(default)]
    pub(crate) roots: Vec<DropRegion>,
    #[serde(default)]
    pub(crate) entries: HashMap<String, Geo>,
    #[serde(default)]
    pub(crate) source: Option<Geo>,
    #[serde(default)]
    pub(crate) style: Style,
}

/// A monitor as reported by `j/monitors`.
#[derive(Clone, Deserialize)]
pub(crate) struct Monitor {
    pub(crate) name: String,
    pub(crate) x: i32,
    pub(crate) y: i32,
    pub(crate) width: i32,
    pub(crate) height: i32,
    #[serde(rename = "refreshRate", default)]
    pub(crate) refresh: f64,
}
