//! Process bootstrap, event-loop wiring and the run loop.

use std::{os::fd::AsFd, path::PathBuf};

use inotify::{Inotify, WatchMask};
use smithay_client_toolkit::{
    compositor::CompositorState,
    output::OutputState,
    reexports::{
        calloop::{
            EventLoop, Interest, Mode, PostAction,
            generic::Generic,
            timer::{TimeoutAction, Timer},
        },
        calloop_wayland_source::WaylandSource,
    },
    registry::RegistryState,
    shell::wlr_layer::LayerShell,
    shm::{Shm, slot::SlotPool},
};
use wayland_client::{Connection, globals::registry_queue_init};

use crate::{
    app::{App, IDLE_INTERVAL},
    instance::{acquire_lock, bind_or_exit, parse_args},
    ipc::hypr_socket,
    model::Handoff,
    overlay::INITIAL_POOL_BYTES,
};

/// Parse arguments, connect to Wayland and run the overlay event loop until it exits.
pub fn run() {
    let state_path = match parse_args() {
        Ok(Some(path)) => path,
        Ok(None) => {
            eprintln!("usage: split-tree-overlay --state <path>");
            std::process::exit(2);
        }
        Err(err) => {
            eprintln!("split-tree-overlay: {err}");
            std::process::exit(2);
        }
    };

    let lock_path = state_path.with_extension("lock");
    let (_lock, replaced) = match acquire_lock(&lock_path) {
        Some(value) => value,
        None => return,
    };

    let connection = match Connection::connect_to_env() {
        Ok(connection) => connection,
        Err(err) => {
            eprintln!("split-tree-overlay: failed to connect to Wayland: {err}");
            std::process::exit(1);
        }
    };

    let (globals, event_queue) = match registry_queue_init(&connection) {
        Ok(parts) => parts,
        Err(err) => {
            eprintln!("split-tree-overlay: failed to enumerate globals: {err}");
            std::process::exit(1);
        }
    };

    let qh = event_queue.handle();
    let compositor = bind_or_exit(CompositorState::bind(&globals, &qh), "wl_compositor");
    let layer_shell = bind_or_exit(LayerShell::bind(&globals, &qh), "wlr-layer-shell");
    let shm = bind_or_exit(Shm::bind(&globals, &qh), "wl_shm");

    let pool = match SlotPool::new(INITIAL_POOL_BYTES, &shm) {
        Ok(pool) => pool,
        Err(err) => {
            eprintln!("split-tree-overlay: failed to create shm pool: {err}");
            std::process::exit(1);
        }
    };

    let inotify = bind_or_exit(Inotify::init(), "inotify");

    let mut event_loop = match EventLoop::try_new() {
        Ok(event_loop) => event_loop,
        Err(err) => {
            eprintln!("split-tree-overlay: failed to create event loop: {err}");
            std::process::exit(1);
        }
    };

    let handle = event_loop.handle();

    if let Err(err) = WaylandSource::new(connection.clone(), event_queue).insert(handle.clone()) {
        eprintln!("split-tree-overlay: failed to add Wayland source: {err}");
        std::process::exit(1);
    }

    // Watch the handoff file's directory so we can detect when it is created, updated, or deleted.
    // We don't watch the file itself because it may be replaced by a new inode on update, and we want to catch that too.
    let watch_dir = state_path
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    let watch_mask = WatchMask::CLOSE_WRITE
        | WatchMask::MODIFY
        | WatchMask::CREATE
        | WatchMask::MOVED_TO
        | WatchMask::DELETE;

    if let Err(err) = inotify.watches().add(&watch_dir, watch_mask) {
        eprintln!(
            "split-tree-overlay: failed to watch {}: {err}",
            watch_dir.display()
        );
        std::process::exit(1);
    }

    let poll_fd = match inotify.as_fd().try_clone_to_owned() {
        Ok(fd) => fd,
        Err(err) => {
            eprintln!("split-tree-overlay: failed to duplicate inotify fd: {err}");
            std::process::exit(1);
        }
    };

    let fs_result = handle.insert_source(
        Generic::new(poll_fd, Interest::READ, Mode::Level),
        |_, _, app: &mut App| {
            app.handle_fs_events();
            Ok(PostAction::Continue)
        },
    );
    if let Err(err) = fs_result {
        eprintln!("split-tree-overlay: failed to add inotify source: {err}");
        std::process::exit(1);
    }

    let timer_result = handle.insert_source(
        Timer::from_duration(IDLE_INTERVAL),
        |_, _, app: &mut App| {
            app.on_tick();
            TimeoutAction::ToDuration(app.timer_interval)
        },
    );
    if let Err(err) = timer_result {
        eprintln!("split-tree-overlay: failed to add cursor timer: {err}");
        std::process::exit(1);
    }

    let state_file_name = state_path
        .file_name()
        .map(|name| name.to_os_string())
        .unwrap_or_default();
    let log_path = state_path.with_extension("log");

    let mut app = App {
        registry_state: RegistryState::new(&globals),
        output_state: OutputState::new(&globals, &qh),
        shm,
        compositor,
        layer_shell,
        connection,
        qh: qh.clone(),
        loop_handle: handle.clone(),
        pool,
        state_path,
        state_file_name,
        inotify,
        last_raw: Vec::new(),
        handoff: Handoff::default(),
        monitors: Vec::new(),
        monitors_at: None,
        cursor: (0.0, 0.0),
        preview: None,
        source: None,
        ipc_command: hypr_socket(".socket.sock"),
        ipc_event: hypr_socket(".socket2.sock"),
        event_connected: false,
        event_stream: None,
        event_buf: String::new(),
        timer_interval: IDLE_INTERVAL,
        log_path,
        log_lines: Vec::new(),
        last_resolved: None,
        ipc_warned: false,
    };

    app.load_monitors();
    app.debug(format!(
        "started pid={} replaced={:?} monitors={} cmd_socket={:?} state={}",
        std::process::id(),
        replaced,
        app.monitors.len(),
        app.ipc_command,
        app.state_path.display()
    ));
    app.poll_state();

    if let Err(err) = event_loop.run(None, &mut app, |_| {}) {
        eprintln!("split-tree-overlay: event loop error: {err}");
        std::process::exit(1);
    }
}
