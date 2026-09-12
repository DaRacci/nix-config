#!/usr/bin/env bash

set -euo pipefail

state_dir=${VFIO_STATE_DIR:-/tmp}
vtconsole_root=${VFIO_VTCONSOLE_ROOT:-/sys/class/vtconsole}
efi_framebuffer_unbind_path=${VFIO_EFI_FRAMEBUFFER_UNBIND_PATH:-/sys/bus/platform/drivers/efi-framebuffer/unbind}

date_stamp=$(date +"%m/%d/%Y %R:%S :")

stop_save_service() {
  local service_name=$1
  local store_suffix=${2:-services}
  local output_file="$state_dir/vfio-store-$store_suffix"

  if systemctl is-active --quiet "$service_name"; then
    touch "$output_file"
    grep -qsF "$service_name" "$output_file" || echo "$service_name" >> "$output_file"
    echo "$date_stamp Stopping $service_name"
    systemctl stop "$service_name"

    while systemctl is-active --quiet "$service_name"; do
      echo "$date_stamp Waiting for $service_name to stop"
      sleep 0.5
    done
  fi
}

stop_services() {
  stop_save_service "display-manager.service"
  systemctl isolate multi-user.target
  stop_save_service "openrgb.service"
}

unbind_vtconsoles() {
  rm -f "$state_dir/vfio-bound-consoles"

  for (( i = 0; i < 16; i++ )); do
    if [ -e "$vtconsole_root/vtcon$i" ]; then
      if [ "$(grep -c 'frame buffer' "$vtconsole_root/vtcon$i/name")" = '1' ]; then
        echo 0 > "$vtconsole_root/vtcon$i/bind"
        echo "$date_stamp Unbinding Console $i"
        echo "$i" >> "$state_dir/vfio-bound-consoles"
      fi
    fi
  done
}

unload_gpu_drivers() {
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    rm -f "$file"
  done < <(find -L "$state_dir" -maxdepth 1 -type f -name 'vfio-is-*' -print)

  if lspci -nn | grep -e VGA | grep -s NVIDIA; then
    echo "$date_stamp System has an NVIDIA GPU"
    echo true > "$state_dir/vfio-is-nvidia"

    if ! printf '%s\n' 'efi-framebuffer.0' > "$efi_framebuffer_unbind_path"; then
      echo "$date_stamp Failed to unbind frame buffer"
    fi

    stop_save_service "nvidia-persistenced.service" nvidia
    sleep 1

    modprobe -r nvidia_uvm
    modprobe -r nvidia_drm
    modprobe -r nvidia_modeset
    modprobe -r nvidia
    modprobe -r i2c_nvidia_gpu
    modprobe -r drm_kms_helper
    modprobe -r drm

    echo "$date_stamp NVIDIA GPU Drivers Unloaded"
  fi

  if lspci -nn | grep -e VGA | grep -s AMD; then
    echo "$date_stamp System has an AMD GPU"
    echo true > "$state_dir/vfio-is-amd"
    printf '%s\n' 'efi-framebuffer.0' > "$efi_framebuffer_unbind_path"

    modprobe -r drm_kms_helper
    modprobe -r amdgpu
    modprobe -r radeon
    modprobe -r drm

    echo "$date_stamp AMD GPU Drivers Unloaded"
  fi
}

load_vfio_drivers() {
  modprobe vfio
  modprobe vfio_pci
  modprobe vfio_iommu_type1
}

echo "$date_stamp Beginning of Startup!"
stop_services
sleep 1
unbind_vtconsoles
sleep 1
unload_gpu_drivers
load_vfio_drivers
echo "$date_stamp End of Startup!"
