#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: per-machine <guest-name> <hook-name> <state-name>"
  exit 1
fi

guest_name=$1
hook_name=$2
state_name=$3
hooks_root=${VIRT_TOOLS_HOOKS_ROOT:-$(dirname "$0")/guests}
hook_path="$hooks_root/$guest_name/$hook_name/$state_name"
log_file=${VIRT_TOOLS_HOOK_LOG_FILE:-/var/log/libvirt/hooks.log}

log() {
  printf '%s\n' "$*" >> "$log_file"
}

case "$hook_name" in
  start)
    systemctl start "libvirt-nosleep@$guest_name"
    ;;
  stopped)
    systemctl stop "libvirt-nosleep@$guest_name"
    ;;
esac

log "Attempting to run $hook_path"
if [ -f "$hook_path" ] && [ -s "$hook_path" ] && [ -x "$hook_path" ]; then
  log "Running $hook_path"
  "$hook_path" "$@"
elif [ -d "$hook_path" ]; then
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    log "Running $file"
    "$file" "$@"
  done < <(find -L "$hook_path" -maxdepth 1 -type f -executable -print)
fi
