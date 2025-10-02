#!/usr/bin/env -S nix shell nixpkgs#nushell --command nu

use std/log

const NOT_HOME_FILES = [
  "os-config.nix"
]

def main [
  symbol: string,
  file: string
] {
  let git_root = git rev-parse --show-toplevel
  let file_path = $file | str trim
  let relative_path = $file | str replace $"($git_root)/" "" | str trim

  mut host = cat /etc/hostname | str trim
  if ($relative_path | str starts-with "hosts/") {
    $host = $relative_path | split row '/' | get 3
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

  let configAttr = if $home != null {
    $"homeConfigurations.($home).config"
  } else {
    $"nixosConfigurations.($host).config"
  }

  (nix eval --quiet --raw --no-pure-eval --expr $'
  let
    flake = builtins.getFlake "($git_root)";
  in flake.($configAttr).($symbol)
  ') e> /dev/null
}
