#!/usr/bin/env bash

set -euo pipefail

port=${SUNSHINE_PROXY_PORT:-47989}
target=${SUNSHINE_PROXY_TARGET:-127.0.0.1:$port}
wait_attempts=${SUNSHINE_PROXY_WAIT_ATTEMPTS:-30}
wait_interval=${SUNSHINE_PROXY_WAIT_INTERVAL:-0.5}
attempt=1

while [ "$attempt" -le "$wait_attempts" ]; do
  if [ -n "$(ss -Htlnp "sport = :$port" 2>/dev/null)" ]; then
    exec systemd-socket-proxyd --exit-idle-time=300s "$target"
  fi

  sleep "$wait_interval"
  attempt=$((attempt + 1))
done

exec systemd-socket-proxyd --exit-idle-time=300s "$target"
