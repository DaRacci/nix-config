//! Overlay application state and its event-driven update loop.

use std::{
    ffi::OsString,
    fs,
    io::Read,
    os::unix::net::UnixStream,
    path::PathBuf,
    time::{Duration, Instant},
};

use inotify::{EventMask, Inotify};
use smithay_client_toolkit::{
    compositor::CompositorState,
    output::OutputState,
    reexports::calloop::{Interest, LoopHandle, Mode, PostAction, generic::Generic},
    registry::RegistryState,
    shell::wlr_layer::LayerShell,
    shm::{Shm, slot::SlotPool},
};
use wayland_client::{Connection, QueueHandle};

use crate::{
    ipc::{ipc_request, parse_cursor},
    model::{Geo, Handoff, Monitor},
    overlay::ActiveSurface,
    paint::parse_hex,
    resolve::resolve,
};

/// Poll cadence while no drag is active.
pub(crate) const IDLE_INTERVAL: Duration = Duration::from_millis(100);
/// Sample cadence when the cursor's monitor refresh rate is unknown.
const FALLBACK_INTERVAL: Duration = Duration::from_millis(16);
/// Lower clamp for the per-monitor sample cadence.
const MIN_INTERVAL: Duration = Duration::from_millis(4);
/// Upper clamp for the per-monitor sample cadence.
const MAX_INTERVAL: Duration = Duration::from_millis(100);
/// How often the monitor list is refreshed during a drag.
const MONITOR_REFRESH: Duration = Duration::from_secs(2);

pub(crate) struct App {
    pub(crate) registry_state: RegistryState,
    pub(crate) output_state: OutputState,
    pub(crate) shm: Shm,
    pub(crate) compositor: CompositorState,
    pub(crate) layer_shell: LayerShell,
    pub(crate) connection: Connection,
    pub(crate) qh: QueueHandle<Self>,
    pub(crate) loop_handle: LoopHandle<'static, Self>,
    pub(crate) pool: SlotPool,
    pub(crate) state_path: PathBuf,
    pub(crate) state_file_name: OsString,
    pub(crate) inotify: Inotify,
    pub(crate) last_raw: Vec<u8>,
    pub(crate) handoff: Handoff,
    pub(crate) monitors: Vec<Monitor>,
    pub(crate) monitors_at: Option<Instant>,
    pub(crate) cursor: (f64, f64),
    pub(crate) preview: Option<ActiveSurface>,
    pub(crate) source: Option<ActiveSurface>,
    pub(crate) ipc_command: Option<PathBuf>,
    pub(crate) ipc_event: Option<PathBuf>,
    pub(crate) event_connected: bool,
    pub(crate) event_stream: Option<UnixStream>,
    pub(crate) event_buf: String,
    pub(crate) timer_interval: Duration,
    pub(crate) log_path: PathBuf,
    pub(crate) log_lines: Vec<String>,
    pub(crate) last_resolved: Option<Geo>,
    pub(crate) ipc_warned: bool,
}

impl App {
    pub(crate) fn handle_fs_events(&mut self) {
        let mut buffer = [0u8; 8192];
        let mut relevant = false;

        for _ in 0..32 {
            let events = match self.inotify.read_events(&mut buffer) {
                Ok(events) => events,
                Err(_) => break,
            };

            for event in events {
                if event.mask.contains(EventMask::Q_OVERFLOW)
                    || event.name == Some(self.state_file_name.as_os_str())
                {
                    relevant = true;
                }
            }
        }

        if relevant {
            self.poll_state();
        }
    }

    pub(crate) fn poll_state(&mut self) {
        let raw = match fs::read(&self.state_path) {
            Ok(raw) => raw,
            Err(_) => {
                if !self.last_raw.is_empty() {
                    self.last_raw.clear();
                    self.handoff = Handoff::default();
                    self.hide_surfaces();
                }
                return;
            }
        };

        if raw == self.last_raw {
            return;
        }

        match serde_json::from_slice::<Handoff>(&raw) {
            Ok(handoff) => {
                self.last_raw = raw;
                self.handoff = handoff;
                if self.handoff.dragging {
                    self.timer_interval = self.sample_interval();
                } else {
                    self.timer_interval = IDLE_INTERVAL;
                    self.hide_surfaces();
                }
                self.debug(format!(
                    "handoff dragging={} regions={} roots={} entries={} source={:?} fill={}",
                    self.handoff.dragging,
                    self.handoff.regions.len(),
                    self.handoff.roots.len(),
                    self.handoff.entries.len(),
                    self.handoff.source.map(|g| (g.x, g.y, g.w, g.h)),
                    self.handoff.style.fill,
                ));
            }
            // Torn write; keep the previous handoff and retry on the next event.
            Err(err) => {
                let preview = String::from_utf8_lossy(&raw)
                    .chars()
                    .take(240)
                    .collect::<String>();
                self.debug(format!("handoff parse error: {err}; raw={preview}"));
            }
        }
    }

    fn hide_surfaces(&mut self) {
        self.preview = None;
        self.source = None;
        self.last_resolved = None;
    }

    // Capped diagnostic log written next to the state file (`<state>.log`).
    // Only records changes and cursor-resolution changes, so it stays small.
    pub(crate) fn debug(&mut self, line: String) {
        self.log_lines.push(line);
        if self.log_lines.len() > 200 {
            self.log_lines.remove(0);
        }
        let _ = fs::write(&self.log_path, self.log_lines.join("\n"));
    }

    pub(crate) fn on_tick(&mut self) {
        if !self.event_connected {
            self.try_connect_events();
        }

        if !self.handoff.dragging {
            self.timer_interval = IDLE_INTERVAL;
            self.hide_surfaces();
            return;
        }

        self.sample_cursor();
        self.refresh_monitors_if_stale();

        let preview_box = self.lookup();
        if preview_box != self.last_resolved {
            self.last_resolved = preview_box;
            self.debug(format!(
                "cursor=({:.0},{:.0}) resolved={:?} regions={} roots={} entries={}",
                self.cursor.0,
                self.cursor.1,
                preview_box.map(|g| (g.x, g.y, g.w, g.h)),
                self.handoff.regions.len(),
                self.handoff.roots.len(),
                self.handoff.entries.len(),
            ));
        }
        let style = self.handoff.style.clone();
        let rounding = style.rounding;
        let fill = parse_hex(&style.fill);
        let border = parse_hex(&style.border);
        let source_border = parse_hex(&style.source_border);

        let preview = self.preview.take();
        self.preview = self.render_rect(
            preview,
            preview_box,
            fill,
            border,
            style.border_width,
            rounding,
        );

        let source = self.source.take();
        self.source = self.render_rect(
            source,
            self.handoff.source,
            [0, 0, 0, 0],
            source_border,
            style.source_border_width,
            rounding,
        );

        self.timer_interval = self.sample_interval();
    }

    fn sample_cursor(&mut self) {
        let Some(path) = self.ipc_command.clone() else {
            return;
        };

        if let Some(text) = ipc_request(&path, "cursorpos") {
            if let Some(cursor) = parse_cursor(&text) {
                self.cursor = cursor;
            }
        } else if !self.ipc_warned {
            self.ipc_warned = true;
            self.debug(format!("cursorpos IPC failed via {}", path.display()));
        }
    }

    pub(crate) fn load_monitors(&mut self) {
        let Some(path) = self.ipc_command.clone() else {
            return;
        };

        let Some(text) = ipc_request(&path, "j/monitors") else {
            return;
        };

        if let Ok(monitors) = serde_json::from_str::<Vec<Monitor>>(&text) {
            self.monitors = monitors;
            self.monitors_at = Some(Instant::now());
        }
    }

    fn refresh_monitors_if_stale(&mut self) {
        let stale = self
            .monitors_at
            .is_none_or(|at| at.elapsed() >= MONITOR_REFRESH);
        if stale {
            self.load_monitors();
        }
    }

    fn try_connect_events(&mut self) {
        let Some(path) = self.ipc_event.clone() else {
            return;
        };

        let Ok(stream) = UnixStream::connect(&path) else {
            return;
        };

        if stream.set_nonblocking(true).is_err() {
            return;
        }

        // calloop's `Generic` only exposes immutable access to its inner fd,
        // so poll one handle and read from a cloned handle of the same socket stored on `App`.
        let Ok(reader) = stream.try_clone() else {
            return;
        };

        let result = self.loop_handle.insert_source(
            Generic::new(stream, Interest::READ, Mode::Level),
            |_, _, app: &mut App| {
                app.handle_event_read();
                Ok(PostAction::Continue)
            },
        );

        if result.is_ok() {
            self.event_stream = Some(reader);
            self.event_connected = true;
        }
    }

    fn handle_event_read(&mut self) {
        let Some(stream) = self.event_stream.as_mut() else {
            return;
        };

        let mut buffer = [0u8; 4096];

        loop {
            match stream.read(&mut buffer) {
                Ok(0) => break,
                Ok(read) => self
                    .event_buf
                    .push_str(&String::from_utf8_lossy(&buffer[..read])),
                Err(err) if err.kind() == std::io::ErrorKind::WouldBlock => break,
                Err(_) => break,
            }
        }

        while let Some(index) = self.event_buf.find('\n') {
            let line = self.event_buf[..index].to_string();
            self.event_buf.drain(..=index);
            self.handle_event_line(&line);
        }
    }

    fn handle_event_line(&mut self, line: &str) {
        if line.starts_with("configreloaded") {
            // A reload resets the Lua drag state; drop the preview so nothing is left stranded.
            self.handoff = Handoff::default();
            self.last_raw.clear();
            self.timer_interval = IDLE_INTERVAL;
            self.hide_surfaces();
        } else if line.starts_with("monitoradded") || line.starts_with("monitorremoved") {
            self.load_monitors();
        }
    }

    fn lookup(&self) -> Option<Geo> {
        resolve(&self.handoff, self.cursor)
    }

    fn sample_interval(&self) -> Duration {
        let Some(monitor) = self.monitor_containing(self.cursor) else {
            return FALLBACK_INTERVAL;
        };

        let refresh = if monitor.refresh > 1.0 {
            monitor.refresh
        } else {
            60.0
        };

        let interval = Duration::from_secs_f64(1.0 / refresh);
        interval.clamp(MIN_INTERVAL, MAX_INTERVAL)
    }

    fn monitor_containing(&self, point: (f64, f64)) -> Option<&Monitor> {
        self.monitors.iter().find(|monitor| {
            point.0 >= monitor.x as f64
                && point.0 <= (monitor.x + monitor.width) as f64
                && point.1 >= monitor.y as f64
                && point.1 <= (monitor.y + monitor.height) as f64
        })
    }

    pub(crate) fn monitor_for_rect(&self, rect: &Geo) -> Option<&Monitor> {
        let center = (rect.x + rect.w / 2.0, rect.y + rect.h / 2.0);

        self.monitor_containing(center)
            .or_else(|| self.monitor_containing(self.cursor))
            .or_else(|| self.monitors.first())
    }
}
