//! Layer-shell surface management and drawing for the overlay.

use smithay_client_toolkit::{
    compositor::Region,
    shell::{
        WaylandSurface,
        wlr_layer::{Anchor, KeyboardInteractivity, Layer, LayerSurface},
    },
};
use wayland_client::{protocol::wl_output, protocol::wl_shm};

use crate::{
    app::App,
    model::{Geo, Monitor},
    paint::paint,
};

const LAYER_NAMESPACE: &str = "split-tree-overlay";
pub(crate) const INITIAL_POOL_BYTES: usize = 256 * 256 * 4;

/// The buffer content a surface was painted with.
/// Position is not included because moving an unchanged-sized preview only needs the layer margins re-committed,
/// not a fresh buffer, and SHM pool slots never shrink once allocated.
pub(crate) type ContentKey = (u32, u32, [u8; 4], [u8; 4], i32, i32);

/// A live overlay surface for one monitor, tracking the last painted content so redundant buffer allocations are skipped.
pub(crate) struct ActiveSurface {
    pub(crate) layer: LayerSurface,
    _region: Option<Region>,
    output_name: String,
    pub(crate) configured: bool,
    pub(crate) drawn: Option<ContentKey>,
}

impl App {
    pub(crate) fn render_rect(
        &mut self,
        surface: Option<ActiveSurface>,
        rect: Option<Geo>,
        fill: [u8; 4],
        border: [u8; 4],
        border_width: i32,
        rounding: i32,
    ) -> Option<ActiveSurface> {
        let rect = rect?;

        if rect.w <= 0.0 || rect.h <= 0.0 {
            return None;
        }

        let monitor = self.monitor_for_rect(&rect).cloned()?;
        let local_x = (rect.x - monitor.x as f64).round() as i32;
        let local_y = (rect.y - monitor.y as f64).round() as i32;

        let mut surface = match surface {
            Some(surface) if surface.output_name == monitor.name => surface,
            _ => self.create_surface(&monitor, &rect),
        };

        let size = (
            rect.w.round().max(1.0) as u32,
            rect.h.round().max(1.0) as u32,
        );
        surface.layer.set_size(size.0, size.1);
        surface.layer.set_margin(local_y, 0, 0, local_x);

        let key: ContentKey = (size.0, size.1, fill, border, border_width, rounding);
        if surface.configured {
            if surface.drawn != Some(key) {
                self.draw_surface(&surface, &rect, fill, border, border_width, rounding);
                surface.drawn = Some(key);
            } else {
                // Content unchanged: only the position moved.
                // The existing buffer is still valid, so just commit the new margins instead of reallocating and repainting.
                surface.layer.commit();
                let _ = self.connection.flush();
            }
        }

        Some(surface)
    }

    fn create_surface(&self, monitor: &Monitor, rect: &Geo) -> ActiveSurface {
        let surface = self.compositor.create_surface(&self.qh);
        let output = self.output_for_name(&monitor.name);
        let layer = self.layer_shell.create_layer_surface(
            &self.qh,
            surface,
            Layer::Overlay,
            Some(LAYER_NAMESPACE),
            output.as_ref(),
        );

        layer.set_anchor(Anchor::TOP | Anchor::LEFT);
        layer.set_exclusive_zone(-1);
        layer.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer.set_size(
            rect.w.round().max(1.0) as u32,
            rect.h.round().max(1.0) as u32,
        );
        layer.set_margin(
            (rect.y - monitor.y as f64).round() as i32,
            0,
            0,
            (rect.x - monitor.x as f64).round() as i32,
        );

        let region = match Region::new(&self.compositor) {
            Ok(region) => {
                layer
                    .wl_surface()
                    .set_input_region(Some(region.wl_region()));
                Some(region)
            }
            Err(err) => {
                eprintln!("split-tree-overlay: failed to create region: {err}");
                None
            }
        };

        layer.commit();

        ActiveSurface {
            layer,
            _region: region,
            output_name: monitor.name.clone(),
            configured: false,
            drawn: None,
        }
    }

    fn draw_surface(
        &mut self,
        surface: &ActiveSurface,
        rect: &Geo,
        fill: [u8; 4],
        border: [u8; 4],
        border_width: i32,
        rounding: i32,
    ) {
        let (width, height) = (rect.w.round() as i32, rect.h.round() as i32);
        if width <= 0 || height <= 0 {
            return;
        }

        let stride = width * 4;
        let (buffer, canvas) =
            match self
                .pool
                .create_buffer(width, height, stride, wl_shm::Format::Argb8888)
            {
                Ok(parts) => parts,
                Err(err) => {
                    eprintln!("split-tree-overlay: failed to create buffer: {err}");
                    return;
                }
            };

        paint(
            canvas,
            width as u32,
            height as u32,
            fill,
            border,
            border_width,
            rounding,
        );

        let wl_surface = surface.layer.wl_surface();
        wl_surface.damage_buffer(0, 0, width, height);

        if let Err(err) = buffer.attach_to(wl_surface) {
            eprintln!("split-tree-overlay: failed to attach buffer: {err}");
            return;
        }

        surface.layer.commit();
        let _ = self.connection.flush();
    }

    fn output_for_name(&self, name: &str) -> Option<wl_output::WlOutput> {
        if name.is_empty() {
            return None;
        }

        self.output_state.outputs().find(|output| {
            self.output_state
                .info(output)
                .and_then(|info| info.name)
                .as_deref()
                == Some(name)
        })
    }
}
