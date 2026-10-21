#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: windows-isolation-start <allowed-cpus>"
  exit 1
fi

allowed=$1
systemctl set-property --runtime -- user.slice "AllowedCPUs=$allowed"
systemctl set-property --runtime -- system.slice "AllowedCPUs=$allowed"
systemctl set-property --runtime -- init.scope "AllowedCPUs=$allowed"
