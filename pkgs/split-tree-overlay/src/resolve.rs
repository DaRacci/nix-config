//! Cursor-to-tile hit testing, matching the Lua layout's drop semantics.

use crate::model::{DropRegion, Geo, Handoff};

/// Resolve a cursor position to the projected tile box it would drop into.
pub(crate) fn resolve(handoff: &Handoff, cursor: (f64, f64)) -> Option<Geo> {
    // Prefer the smallest containing window tile across all visible workspaces.
    if let Some(region) = smallest_containing(&handoff.regions, cursor) {
        let direction = direction_in(&region.geometry, cursor);
        return handoff
            .entries
            .get(&format!("{}|{}", region.id, direction))
            .copied();
    }

    // Still over the dragged window
    if let Some(source) = handoff.source
        && point_in(&source, cursor)
    {
        return Some(source);
    }

    // Otherwise the workspace edge under the cursor.
    if let Some(root) = smallest_containing(&handoff.roots, cursor) {
        let direction = direction_in(&root.geometry, cursor);
        return handoff
            .entries
            .get(&format!("{}|{}", root.id, direction))
            .copied();
    }

    None
}

fn point_in(rect: &Geo, point: (f64, f64)) -> bool {
    point.0 >= rect.x
        && point.0 <= rect.x + rect.w
        && point.1 >= rect.y
        && point.1 <= rect.y + rect.h
}

fn smallest_containing(regions: &[DropRegion], point: (f64, f64)) -> Option<&DropRegion> {
    let mut best: Option<&DropRegion> = None;
    for region in regions {
        if point_in(&region.geometry, point)
            && best.is_none_or(|current| area(&region.geometry) < area(&current.geometry))
        {
            best = Some(region);
        }
    }

    best
}

fn area(rect: &Geo) -> f64 {
    rect.w * rect.h
}

/// Must match Lua's `directionForPointInBox`
/// Provides a normalised cursor offset per axis.
fn direction_in(rect: &Geo, point: (f64, f64)) -> &'static str {
    let half_w = rect.w / 2.0;
    let half_h = rect.h / 2.0;
    let nx = if half_w > 0.0 {
        (point.0 - (rect.x + half_w)) / half_w
    } else {
        0.0
    };
    let ny = if half_h > 0.0 {
        (point.1 - (rect.y + half_h)) / half_h
    } else {
        0.0
    };

    if nx.abs() >= ny.abs() {
        if nx < 0.0 { "left" } else { "right" }
    } else if ny < 0.0 {
        "up"
    } else {
        "down"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"{
        "dragging": true,
        "regions": [ { "id": "1:r", "box": { "x": 500, "y": 0, "w": 500, "h": 1000 } } ],
        "roots": [ { "id": "1:root", "box": { "x": 0, "y": 0, "w": 1000, "h": 1000 } } ],
        "entries": {
            "1:r|right": { "x": 500, "y": 0, "w": 500, "h": 1000 },
            "1:root|left": { "x": 0, "y": 0, "w": 500, "h": 1000 }
        },
        "source": { "x": 500, "y": 0, "w": 500, "h": 1000 },
        "style": { "fill": "2ac3de33", "border": "2ac3decc", "border_width": 2, "rounding": 8 }
    }"#;

    #[test]
    fn resolves_window_region() {
        let handoff: Handoff = serde_json::from_str(SAMPLE).expect("sample parses");
        assert!(handoff.dragging);
        assert_eq!(handoff.regions.len(), 1);
        assert_eq!(handoff.roots.len(), 1);

        let resolved = resolve(&handoff, (750.0, 500.0)).expect("resolves a window tile");
        assert_eq!(
            (resolved.x, resolved.y, resolved.w, resolved.h),
            (500.0, 0.0, 500.0, 1000.0)
        );
    }

    #[test]
    fn resolves_workspace_root_edge() {
        let handoff: Handoff = serde_json::from_str(SAMPLE).expect("sample parses");
        let resolved = resolve(&handoff, (250.0, 500.0)).expect("resolves a root edge");
        assert_eq!(
            (resolved.x, resolved.y, resolved.w, resolved.h),
            (0.0, 0.0, 500.0, 1000.0)
        );
    }

    #[test]
    fn resolves_fractional_boxes() {
        let json = r#"{
            "dragging": true,
            "regions": [ { "id": "1:r", "box": { "x": 500.5, "y": 0.0, "w": 500.25, "h": 1000.0 } } ],
            "roots": [ { "id": "1:root", "box": { "x": 0.0, "y": 0.0, "w": 1000.75, "h": 1000.0 } } ],
            "entries": { "1:r|right": { "x": 500.5, "y": 0.0, "w": 500.25, "h": 1000.0 } },
            "source": { "x": 0.0, "y": 0.0, "w": 500.0, "h": 1000.0 }
        }"#;

        let handoff: Handoff = serde_json::from_str(json).expect("fractional sample parses");
        let resolved = resolve(&handoff, (900.0, 500.0)).expect("resolves a fractional tile");
        assert_eq!(resolved.w, 500.25);
    }
}
