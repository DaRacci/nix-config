#!/usr/bin/env -S nix shell nixpkgs#nushell nixpkgs#jq --command nu

use std/log

def main [
  type: string,
  object: string
] {
  let thisSource = nix flake archive --json | jq -r '.path'

  let all_imports = if $type == "OS" {
      nix eval --json $".#nixosConfigurations.($object)" --apply $"(cat ./utils/get-os-imports.nix)" | from json
  } else if $type == "HOME" {
      nix eval --json $".#homeConfigurations.($object)" --apply $"(cat ./utils/get-hm-imports.nix)" | from json
  } else {
      log critical "Invalid type: $type; expected 'OS' or 'HOME'"
      exit 1
  }

  let our_imports = $all_imports
    | filter { $in | str starts-with $thisSource }
    | each { $in | str substring (($thisSource | str length) + 1)..  }

  echo $our_imports | to json
}
