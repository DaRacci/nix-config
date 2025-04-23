#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq

set -euo pipefail

LET_IMPORT_EXTENSIONS=$(cat <<EOF
let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  extensions = import ./modules/home-manager/purpose/development/editors/vscode/extensions.nix {
    inherit pkgs lib;
  };
in
EOF
)

extensions=$(nix eval --impure --json --expr "$LET_IMPORT_EXTENSIONS extensions")
extensions=($(echo "$extensions" | jq -r 'to_entries | map(.key as $author | .value | to_entries | map($author + "." + .key)) | flatten | join("\n")'))

for extension in "${extensions[@]}"; do
  echo "Building $extension..."
  nix build --impure --no-link --expr "$LET_IMPORT_EXTENSIONS extensions.${extension}"
done
