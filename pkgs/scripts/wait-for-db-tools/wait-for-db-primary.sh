#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "Usage: wait-for-db-primary <hostname>"
  exit 1
fi

db_hostname=$1
max_attempts=${WAIT_FOR_DB_MAX_ATTEMPTS:-150}
retry_interval=${WAIT_FOR_DB_RETRY_INTERVAL:-2}
attempt=1

while [ "$attempt" -le "$max_attempts" ]; do
  if getent hosts "$db_hostname" >/dev/null 2>&1 && ping -c1 -W1 "$db_hostname" >/dev/null 2>&1; then
    exit 0
  fi

  sleep "$retry_interval"
  attempt=$((attempt + 1))
done

echo "WARNING: database primary host not reachable after timeout, continuing boot without it" >&2
exit 0
