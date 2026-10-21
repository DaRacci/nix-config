#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  alloy-dynamic-capture-ctl [options] [enable [ttl_seconds]|disable|status]

Options:
  --state-file PATH            State file path.
  --never-match-regex REGEX    Regex used to disable drops/limits.
  --default-ttl SECONDS        Default TTL when enable has no ttl argument.
  --max-ttl SECONDS            Maximum allowed TTL.
EOF
}

state_file=""
never_match_regex=""
default_ttl=""
max_ttl=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file)
      state_file="$2"
      shift 2
      ;;
    --never-match-regex)
      never_match_regex="$2"
      shift 2
      ;;
    --default-ttl)
      default_ttl="$2"
      shift 2
      ;;
    --max-ttl)
      max_ttl="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -* )
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ -z "$state_file" || -z "$never_match_regex" || -z "$default_ttl" || -z "$max_ttl" ]]; then
  echo "Missing required options." >&2
  usage >&2
  exit 2
fi

restart_alloy() {
  systemctl restart alloy.service
}

print_status() {
  if [ -f "$state_file" ]; then
    echo '{"mode":"expanded"}'
  else
    echo '{"mode":"default"}'
  fi
}

enable_mode() {
  local ttl="${1:-$default_ttl}"

  case "$ttl" in
    ''|*[!0-9]*)
      echo "ttl must be integer seconds" >&2
      exit 2
      ;;
  esac

  if [ "$ttl" -lt 1 ]; then
    echo "ttl must be >= 1" >&2
    exit 2
  fi

  if [ "$ttl" -gt "$max_ttl" ]; then
    echo "ttl must be <= $max_ttl" >&2
    exit 2
  fi

  mkdir -p "$(dirname "$state_file")"

  cat > "$state_file" <<EOF
ALLOY_DROP_UNITS_REGEX=$never_match_regex
ALLOY_DROP_LEVELS_REGEX=$never_match_regex
ALLOY_LIMIT_LEVELS_REGEX=$never_match_regex
EOF

  restart_alloy

  local unit
  unit="alloy-dynamic-capture-disable-$(date +%s%N)"
  systemd-run \
    --unit "$unit" \
    --on-active "${ttl}s" \
    --service-type oneshot \
    "$0" \
    --state-file "$state_file" \
    --never-match-regex "$never_match_regex" \
    --default-ttl "$default_ttl" \
    --max-ttl "$max_ttl" \
    disable >/dev/null

  echo '{"mode":"expanded"}'
}

disable_mode() {
  rm -f "$state_file"
  restart_alloy
  echo '{"mode":"default"}'
}

command="${1:-status}"
if [ $# -gt 0 ]; then
  shift
fi

case "$command" in
  enable)
    enable_mode "${1:-}"
    ;;
  disable)
    disable_mode
    ;;
  status)
    print_status
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
