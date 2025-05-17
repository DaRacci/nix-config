#!/usr/bin/env nix-shell
#!nix-shell -i nu -p nushell nix jq

def main [
  type: string,
  system: string
] {
  let thisSource = nix flake archive --json | jq -r '.path'

  let all_imports = if $type == "OS" {
      nix eval --impure --json $".#nixosConfigurations.($system)" --apply $"(cat ./utils/get-os-imports.nix)" | from json
  } else if $type == "HOME" {
      nix eval --impure --json $".#homeConfigurations.($system)" --apply $"(cat ./utils/get-hm-imports.nix)" | from json
  } else {
      echo "Invalid type. Use 'OS' or 'HOME'."
      return
  }

  let our_imports = $all_imports
    | filter { $in | str starts-with $thisSource }
    | each { $in | str substring (($thisSource | str length) + 1)..  }

  echo $our_imports | to json
}
