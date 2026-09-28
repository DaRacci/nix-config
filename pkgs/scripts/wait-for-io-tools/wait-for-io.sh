#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: wait-for-io <hostname>"
  exit 1
fi

io_hostname=$1
max_attempts=${WAIT_FOR_IO_MAX_ATTEMPTS:-150}
retry_interval=${WAIT_FOR_IO_RETRY_INTERVAL:-2}
attempt=1

while [ "$attempt" -le "$max_attempts" ]; do
  if getent hosts "$io_hostname" >/dev/null 2>&1 && ping -c1 -W1 "$io_hostname" >/dev/null 2>&1; then
    exit 0
  fi

  sleep "$retry_interval"
  attempt=$((attempt + 1))
done

echo "WARNING: IO Hosts not reachable after timeout, continuing boot without IO Host" >&2
exit 0
