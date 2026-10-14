//! Minimal Hyprland IPC helpers

use std::{
    io::{Read, Write},
    os::unix::net::UnixStream,
    path::{Path, PathBuf},
    time::Duration,
};

const IPC_TIMEOUT: Duration = Duration::from_millis(100);

/// Resolve a socket under the current Hyprland instance directory.
pub(crate) fn hypr_socket(name: &str) -> Option<PathBuf> {
    let runtime = std::env::var("XDG_RUNTIME_DIR").ok()?;
    let signature = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?;
    Some(PathBuf::from(format!("{runtime}/hypr/{signature}/{name}")))
}

/// Send a single command to the command socket and read the full reply.
pub(crate) fn ipc_request(path: &Path, command: &str) -> Option<String> {
    let mut stream = UnixStream::connect(path).ok()?;
    let _ = stream.set_read_timeout(Some(IPC_TIMEOUT));
    let _ = stream.set_write_timeout(Some(IPC_TIMEOUT));

    stream.write_all(command.as_bytes()).ok()?;
    stream.flush().ok()?;

    let mut out = String::new();
    stream.read_to_string(&mut out).ok()?;
    Some(out)
}

/// Parse the `x,y` reply from the `cursorpos` request.
pub(crate) fn parse_cursor(text: &str) -> Option<(f64, f64)> {
    let (x, y) = text.trim().split_once(',')?;
    Some((x.trim().parse().ok()?, y.trim().parse().ok()?))
}
