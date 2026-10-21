#!/usr/bin/env bash

set -euo pipefail

state_file=${SUNSHINE_MONITOR_STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-disabled-monitors-pre-sunshine.json}
mkdir -p "$(dirname "$state_file")"

enabled_monitors=$(hyprctl -j monitors | jq '. - map(select((.name | contains("HEADLESS")) or .disabled == true))')
printf '%s\n' "$enabled_monitors" > "$state_file"

while IFS= read -r monitor; do
  [ -n "$monitor" ] || continue
  hyprctl eval "hl.monitor({ output = \"$monitor\", disabled = true })"
done < <(jq -r '.[].name' "$state_file")
