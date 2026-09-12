#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: swfs-mount-hook <prepare|stop|health> ..."
}

prepare_mount() {
  local mount_path=$1
  local uid=$2
  local gid=$3

  install -d -m 0755 "$mount_path"

  if [ "$uid" != "-" ] && [ "$gid" != "-" ]; then
    chown "$uid:$gid" "$mount_path"
  elif [ "$uid" != "-" ]; then
    chown "$uid" "$mount_path"
  elif [ "$gid" != "-" ]; then
    chgrp "$gid" "$mount_path"
  fi
}

stop_mount() {
  local mount_path=$1

  if mountpoint -q "$mount_path"; then
    fusermount3 -u "$mount_path" 2>/dev/null \
      || fusermount -uz "$mount_path" 2>/dev/null \
      || umount -l "$mount_path" 2>/dev/null \
      || true
  fi
}

health_check_mount() {
  local mount_path=$1
  local timeout_window=$2
  local mount_unit_service=$3
  local restart_services_csv=$4
  local reload_services_csv=$5
  local service

  if mountpoint -q "$mount_path" && timeout --foreground "$timeout_window" stat "$mount_path" >/dev/null 2>&1; then
    exit 0
  fi

  stop_mount "$mount_path"
  systemctl restart "$mount_unit_service"

  IFS=, read -r -a restart_services <<< "$restart_services_csv"
  for service in "${restart_services[@]}"; do
    [ -n "$service" ] || continue
    systemctl restart "$service"
  done

  IFS=, read -r -a reload_services <<< "$reload_services_csv"
  for service in "${reload_services[@]}"; do
    [ -n "$service" ] || continue
    systemctl reload "$service"
  done
}

command_name=${1:-}
shift || true

case "$command_name" in
  prepare)
    if [ $# -ne 3 ]; then
      usage
      exit 1
    fi
    prepare_mount "$1" "$2" "$3"
    ;;
  stop)
    if [ $# -ne 1 ]; then
      usage
      exit 1
    fi
    stop_mount "$1"
    ;;
  health)
    if [ $# -ne 5 ]; then
      usage
      exit 1
    fi
    health_check_mount "$1" "$2" "$3" "$4" "$5"
    ;;
  *)
    usage
    exit 1
    ;;
esac
