//! Process lifecycle helpers: argument parsing, single-instance lock, fail-fast global binding.

use std::{
    fs::{self, File, OpenOptions},
    io::{Seek, SeekFrom, Write},
    path::{Path, PathBuf},
    time::Duration,
};

use lexopt::prelude::*;

/// Parse `--state <path>` (or `--state=<path>`).
///
/// Returns `Ok(None)` when no state path was given, and an error for unknown arguments or a missing value.
pub(crate) fn parse_args() -> Result<Option<PathBuf>, lexopt::Error> {
    let mut parser = lexopt::Parser::from_env();
    let mut state = None;

    while let Some(arg) = parser.next()? {
        match arg {
            Long("state") => state = Some(parser.value()?.into()),
            Long("help") => {
                println!("usage: split-tree-overlay --state <path>");
                std::process::exit(0);
            }
            _ => return Err(arg.unexpected()),
        }
    }

    Ok(state)
}

/// Acquire the single-instance lock.
/// If a different version of this binary holds it, terminate that copy and wait for the lock,
/// so a rebuilt binary replaces the stale one instead of silently no-op'ing.
///
/// Returns the held lock file plus the PID that was replaced, or `None` when the lock was not freed.
pub(crate) fn acquire_lock(path: &Path) -> Option<(File, Option<u32>)> {
    let file = OpenOptions::new()
        .create(true)
        .read(true)
        .write(true)
        .truncate(false)
        .open(path)
        .ok()?;

    if file.try_lock().is_ok() {
        write_pid(&file);
        return Some((file, None));
    }

    let mut replaced = None;
    if let Some(pid) = read_pid(path) {
        match (process_exe(pid), std::env::current_exe().ok()) {
            // The same binary already holds the lock (e.g. a config reload re-launched us):
            // leave it running and exit, so the reload stays a no-op.
            (Some(holder), Some(current)) if holder == current => return None,
            // A different build holds the lock: terminate it so the rebuilt binary can take over.
            (Some(_), Some(_)) => {
                unsafe {
                    libc::kill(pid, libc::SIGTERM);
                }
                replaced = Some(pid as u32);
            }
            // Could not identify the holder; fall through and wait for the lock to free up.
            _ => {}
        }
    }

    for _ in 0..100 {
        std::thread::sleep(Duration::from_millis(10));
        if file.try_lock().is_ok() {
            write_pid(&file);
            return Some((file, replaced));
        }
    }

    None
}

fn write_pid(file: &File) {
    let _ = file.set_len(0);
    let mut handle = file;
    let _ = handle.seek(SeekFrom::Start(0));
    let _ = writeln!(handle, "{}", std::process::id());
}

fn read_pid(path: &Path) -> Option<i32> {
    let text = fs::read_to_string(path).ok()?;
    text.trim().parse().ok()
}

fn process_exe(pid: i32) -> Option<PathBuf> {
    fs::read_link(format!("/proc/{pid}/exe")).ok()
}

/// Bind a Wayland global, exiting with a diagnostic if it is unavailable.
pub(crate) fn bind_or_exit<T, E: std::fmt::Display>(result: Result<T, E>, name: &str) -> T {
    match result {
        Ok(value) => value,
        Err(err) => {
            eprintln!("split-tree-overlay: {name} unavailable: {err}");
            std::process::exit(1);
        }
    }
}
