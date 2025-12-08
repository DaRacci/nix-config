#!/usr/bin/env nu

use lib/flake.nu *

def main [...args: string] {
  let selected = select_host
  let top_level = $".#nixosConfigurations.($selected).config.system.build.toplevel"
  nix build --no-link --accept-flake-config $top_level
  nix-tree $top_level
}
