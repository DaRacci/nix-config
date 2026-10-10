#!/usr/bin/env bash
# shellcheck shell=bash
#
# Install the Hunspell en_AU dictionary into the Vale StylesPath so that
# AU-English.Spelling can find it at <StylesPath>/config/dictionaries.
#
# The dictionary is sourced from nixpkgs (`hunspellDicts.en_AU`) rather than
# vendored into the repository; the two files it installs are .gitignore'd.
#
# Usage:
#   ci/vale/install-dictionaries.sh [<hunspellDicts.en_AU store path>]
#
# If no path is given, the HUNSPELL_EN_AU environment variable is used, and
# failing that the derivation is built from nixpkgs.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
dest="$repo_root/ci/vale/styles/config/dictionaries"

dict_path=${1:-${HUNSPELL_EN_AU:-}}
if [ -z "$dict_path" ]; then
  dict_path=$(nix build --no-link --print-out-paths 'nixpkgs#hunspellDicts.en_AU')
fi

src="$dict_path/share/hunspell"
if [ ! -f "$src/en_AU.dic" ] || [ ! -f "$src/en_AU.aff" ]; then
  echo "error: $src does not contain en_AU.dic / en_AU.aff" >&2
  exit 1
fi

mkdir -p "$dest"
install -m 0444 "$src/en_AU.dic" "$dest/en_AU.dic"
install -m 0444 "$src/en_AU.aff" "$dest/en_AU.aff"
echo "Installed en_AU.{dic,aff} into $dest"
