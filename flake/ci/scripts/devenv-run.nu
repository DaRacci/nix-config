#!/usr/bin/env nu

use std/log
use lib/common.nu

# Run a command inside a devenv shell.
#
# The devenv flake input needs a real path, so initialise `.devenv/root` first and pass it via `--override-input`.
# Use `--init-only` when a step only needs the root file (for example `nix flake check`).
#
# Put `--` before the command when it takes its own flags, for example
# `devenv-run -- -- nix-update --flake foo`.
def main [
  --shell: string = "default" # Devshell attribute under the flake
  --init-only # Only initialise .devenv/root
  ...command: string # Command to run inside the devshell
] {
  if not (".devenv" | path exists) {
    mkdir .devenv
  }

  let root = (pwd)
  $root | save --force .devenv/root

  if $init_only {
    log info "Initialised .devenv/root"
    return
  }

  if ($command | is-empty) {
    log error "No command provided"
    exit 1
  }

  nix develop $".#($shell)" --override-input devenv-root $"file+file://($root)/.devenv/root" --accept-flake-config --command ...$command
}
