#!/usr/bin/env bash

socket_path="${SSH_RELAY_SOCKET_PATH:-/home/racci/.ssh/wsl-ssh-agent.sock}"
pipe_command="${SSH_RELAY_TARGET_COMMAND:-/home/racci/.local/bin/npiperelay.exe -ei -s //./pipe/openssh-ssh-agent}"
socat_path=$(command -v socat)

start() {
  if [ -S "$socket_path" ]; then
    echo "removing previous socket..."
    rm "$socket_path"
  fi

  echo "Starting SSH-Agent relay..."
  (setsid "$socat_path" "UNIX-LISTEN:${socket_path},fork" "EXEC:${pipe_command},nofork" &) >/dev/null 2>&1
}

stop() {
  echo "Stopping SSH-Agent relay..."
  if [ -S "$socket_path" ]; then
    rm "$socket_path"
  fi
}

status() {
  if [ ! -S "$socket_path" ]; then
    echo "SSH-Agent relay is not running."
    return 0
  fi

  if ! pgrep -fx "^${socat_path}\\s.+" >/dev/null; then
    echo "SSH-Agent relay is not running."
    return 0
  fi

  echo "Polling remote ssh-agent..."
  if SSH_AUTH_SOCK="$socket_path" ssh-add -L >/dev/null 2>&1; then
    echo "SSH-Agent relay is running and working."
    return 0
  fi

  res=$?
  if [ "$res" -ge 2 ]; then
    echo "[$res] Failure communicating with ssh-agent"
    exit 1
  fi

  echo "SSH-Agent relay is running but not working."
}

case "${1:-}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  *)
    echo "Usage: ssh-relay [start|stop|status]"
    exit 1
    ;;
esac
