#!/usr/bin/env nu

use std/log

def main [
  --flake-dirs: list<string>  # List of flake directories to update; relative to the repository root.
  --commit-message: string    # Commit message template; <flake> will be replaced with the relative path of the flake.lock file.
] {
  if (($flake_dirs | length) == 0) {
    log warning "No flake directories provided to update. Exiting."
    exit
  }

  log info $"Received flake directories to update: ($flake_dirs | str join ",")";

  let ROOT_DIR = git rev-parse --show-toplevel | str trim
  let HEAD_COMMIT = git rev-parse HEAD | str trim

  $flake_dirs | each {|flake_dir|
    let subdir = path join $ROOT_DIR $flake_dir
    if not ($subdir | path exists) {
      log warning $"Flake directory ($flake_dir) does not exist, skipping..."
      return
    }

    cd $subdir
    let commit_msg = $commit_message | str replace "<flake>" $flake_dir
    try {
      nix flake update --commit-lock-file --commit-lock-file-summary -m $commit_msg
    } catch { |err|
      log error $"Failed to update flake in ($flake_dir), continuing..."
      log debug $"Error details: ($err.msg)"
    }
    cd $ROOT_DIR
  }

  let NEW_HEAD_COMMIT = git rev-parse HEAD | str trim
  if $HEAD_COMMIT == $NEW_HEAD_COMMIT {
    log info "No updates to flake.lock files were made."
  }
}
