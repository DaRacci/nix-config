#!/usr/bin/env bash

set -euo pipefail

state_dir=${VFIO_STATE_DIR:-/tmp}
vtconsole_root=${VFIO_VTCONSOLE_ROOT:-/sys/class/vtconsole}
date_stamp=$(date +"%m/%d/%Y %R:%S :")

start_service_from_input() {
  local suffix=$1
  local input_file="$state_dir/vfio-store-$suffix"
  local service_name

  if [ ! -e "$input_file" ]; then
    return 0
  fi

  while IFS= read -r service_name; do
    [ -n "$service_name" ] || continue
    if command -v systemctl >/dev/null; then
      echo "$date_stamp Starting $service_name"
      systemctl start "$service_name"
    fi
  done < "$input_file"
}

unload_vfio_drivers() {
  modprobe -r vfio_pci
  modprobe -r vfio_iommu_type1
  modprobe -r vfio
}

load_gpu_drivers() {
  if [ -e "$state_dir/vfio-is-nvidia" ] && grep -q true "$state_dir/vfio-is-nvidia"; then
    echo "$date_stamp Loading NVIDIA GPU Drivers"

    modprobe drm
    modprobe drm_kms_helper
    modprobe i2c_nvidia_gpu
    modprobe nvidia
    modprobe nvidia_modeset
    modprobe nvidia_drm
    modprobe nvidia_uvm

    start_service_from_input nvidia
    echo "$date_stamp NVIDIA GPU Drivers Loaded"
  fi

  if [ -e "$state_dir/vfio-is-amd" ] && grep -q true "$state_dir/vfio-is-amd"; then
    echo "$date_stamp Loading AMD GPU Drivers"

    modprobe drm
    modprobe amdgpu
    modprobe radeon
    modprobe drm_kms_helper

    echo "$date_stamp AMD GPU Drivers Loaded"
  fi
}

bind_vtconsoles() {
  local input_file="$state_dir/vfio-bound-consoles"
  local console_number

  if [ ! -e "$input_file" ]; then
    echo "$date_stamp No consoles to rebind"
    return 0
  fi

  while IFS= read -r console_number; do
    [ -n "$console_number" ] || continue
    if [ -e "$vtconsole_root/vtcon$console_number" ]; then
      if [ "$(grep -c 'frame buffer' "$vtconsole_root/vtcon$console_number/name")" = '1' ]; then
        echo "$date_stamp Rebinding console $console_number"
        echo 1 > "$vtconsole_root/vtcon$console_number/bind"
      fi
    fi
  done < "$input_file"
}

echo "$date_stamp Beginning of Teardown!"
unload_vfio_drivers
load_gpu_drivers
start_service_from_input services
bind_vtconsoles
echo "$date_stamp End of Teardown!"
