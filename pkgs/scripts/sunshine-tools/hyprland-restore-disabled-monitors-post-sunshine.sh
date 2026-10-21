#!/usr/bin/env bash

set -euo pipefail

state_file=${SUNSHINE_MONITOR_STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-disabled-monitors-pre-sunshine.json}
if [ ! -f "$state_file" ]; then
  exit 0
fi

while IFS= read -r monitor; do
  [ -n "$monitor" ] || continue
  hyprctl eval "hl.monitor({ output = \"$monitor\", disabled = false })"
done < <(jq -r '.[].name' "$state_file")

rm -f "$state_file"
