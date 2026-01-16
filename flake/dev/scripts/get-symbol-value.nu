#!/usr/bin/env -S nix shell nixpkgs#nushell --command nu

use lib/common.nu
use lib/flake.nu *

const NOT_HOME_FILES = [
  "os-config.nix"
]

def main [
  symbol: string,
  file: string
] {
  let relative_path = ($file | str trim | str replace $"($env.GIT_ROOT)/" "")

  mut host = $env.CURRENT_HOST
  if ($relative_path | str starts-with "hosts/") {
    $host = $relative_path | split row '/' | get 2
  }

  mut home = null
  if ($relative_path | str starts-with "home/") {
    let split = $relative_path | split row '/'
    $home = $split | get 1

    let file_name = $split | last
    if ($NOT_HOME_FILES | any { $in == $file_name }) {
      $home = null
    }
  }

  let config_attr = if $home != null {
    $"homeConfigurations.($home).config"
  } else {
    $"nixosConfigurations.($host).config"
  }

  (flake-eval $"flake.($config_attr).($symbol)" --raw) e> /dev/null | str trim
}
