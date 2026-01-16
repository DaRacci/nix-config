#!/usr/bin/env nu

use lib/common.nu
use lib/flake.nu *

def main [] {
  let selected = select_host --fast
  let top_level = $".#nixosConfigurations.($selected).config.system.build.toplevel"
  nix build --no-link --accept-flake-config $top_level
  nix-tree $top_level
}
