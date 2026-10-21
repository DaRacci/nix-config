#!/usr/bin/env bash

if [ $# -lt 2 ]; then
  echo "Usage: ssh-to-age-keys <output-dir> <ssh-key-path>..."
  exit 1
fi

output_dir=$1
shift

output_file="${output_dir}/keys.txt"
mkdir -p "$output_dir"
rm -f "$output_file"

declare -A seen_hashes=()
for ssh_key_path in "$@"; do
  if [ ! -f "$ssh_key_path" ]; then
    continue
  fi

  key_hash=$(sha256sum "$ssh_key_path")
  key_hash=${key_hash%% *}

  if [ -n "${seen_hashes[$key_hash]:-}" ]; then
    continue
  fi

  seen_hashes["$key_hash"]=1
  ssh-to-age --private-key -i "$ssh_key_path" >> "$output_file"
done
