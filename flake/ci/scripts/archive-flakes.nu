#!/usr/bin/env nu

use std/log

def main [
  ...flake_dirs: string  # List of flake directories to archive; relative to the repository root.
] {
  if (($flake_dirs | length) == 0) {
    log warning "No flake directories provided to update. Exiting."
    exit
  }

  log info $"Received flake directories to archive: ($flake_dirs | str join ",")";

  let ROOT_DIR = git rev-parse --show-toplevel | str trim

  for flake_dir in $flake_dirs {
    let subdir = $ROOT_DIR | path join $flake_dir
    if not ($subdir | path exists) {
      log warning $"Flake directory ($flake_dir) does not exist, skipping..."
      return
    }

    cd $subdir
    try {
      nix flake archive
    } catch { |err|
      log error "There was an issue while archiving, idk man"
      log error $"Error details: ($err.msg)"
    }
    cd $ROOT_DIR
  }
}
