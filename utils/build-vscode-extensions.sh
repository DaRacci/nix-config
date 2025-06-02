#!/usr/bin/env -S nix shell nixpkgs#jq --command bash
# shellcheck shell=bash disable=SC1008

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

extensions=$(nix eval --no-pure-eval --json --expr "$LET_IMPORT_EXTENSIONS extensions")
mapfile -t extensions < <(echo "$extensions" | jq -r 'to_entries | map(.key as $author | .value | to_entries | map($author + "." + .key)) | flatten | join("\n")')

for extension in "${extensions[@]}"; do
  echo "Building $extension..."
  nix build --no-pure-eval --no-link --expr "$LET_IMPORT_EXTENSIONS extensions.${extension}"
done
