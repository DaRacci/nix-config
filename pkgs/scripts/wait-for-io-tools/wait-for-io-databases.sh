#!/usr/bin/env bash

if [ $# -ne 3 ]; then
  echo "Usage: wait-for-io-databases <hostname> <postgres-port-or-empty> <redis-port-or-empty>"
  exit 1
fi

io_hostname=$1
postgres_port=$2
redis_port=$3
max_attempts=${WAIT_FOR_IO_DATABASE_MAX_ATTEMPTS:-60}
retry_interval=${WAIT_FOR_IO_DATABASE_RETRY_INTERVAL:-5}
attempt=1

echo "Waiting for an IO database to become available..."

while [ "$attempt" -le "$max_attempts" ]; do
  all_ok=true

  if [ -n "$postgres_port" ]; then
    if ! pg_isready -h "$io_hostname" -p "$postgres_port" -t 5 >/dev/null 2>&1; then
      echo "Attempt $attempt/$max_attempts: PostgreSQL not ready at $io_hostname:$postgres_port"
      all_ok=false
    else
      echo "PostgreSQL is ready"
    fi
  fi

  if [ -n "$redis_port" ]; then
    if ! redis-cli -h "$io_hostname" -p "$redis_port" ping >/dev/null 2>&1; then
      echo "Attempt $attempt/$max_attempts: Redis not ready at $io_hostname:$redis_port"
      all_ok=false
    else
      echo "Redis is ready"
    fi
  fi

  if [ "$all_ok" = true ]; then
    echo "All IO databases are available"
    exit 0
  fi

  attempt=$((attempt + 1))
  sleep "$retry_interval"
done

echo "Timeout waiting an IO database after $max_attempts attempts"
exit 1
