#!/usr/bin/env bash

HOME_PREFIX="home/*"
CONFIG_PREFIX="$HOME_PREFIX/.config"
SHARE_PREFIX="$HOME_PREFIX/.local/share"

EXCLUDE=(
  "etc/passwd"
  "etc/NIXOS"
  "etc/group"
  "etc/machine-id"
  "etc/resolve.conf"
  "etc/ssh"
  "etc/shadow"
  "etc/subgid"
  "etc/subuid"
  "etc/sudoers"

  var/lib/libvirt/{qemu.conf,nwfilter,dnsmasq}
  "var/cache"
  "var/.updated"
  "var/lib/NetworkManager/timestamps"
  "var/lib/dhcpcd"

  "**/*logs"
  "**/*log"

  "tmp"

  "$HOME_PREFIX/.cache"

  "$HOME_PREFIX/.mozilla/firefox/*/cache2/entries"
  "$HOME_PREFIX/.steam"
  "$HOME_PREFIX/.pki"
  "$HOME_PREFIX/.pulse-cookie"
  "$HOME_PREFIX/.local/state/wireplumber"
  "$SHARE_PREFIX/vulkan/implicit_layer.d"
  "$CONFIG_PREFIX/BambuStudio"
  "$CONFIG_PREFIX/**/com.1password.1password.json"
)

ELECTRON_APPS=(
  "$CONFIG_PREFIX"/{Code,SideQuest,1Password}
  "$CONFIG_PREFIX"/1Password/Partitions/1password
)

ELECTRON_RELATIVE_PATHS=(
  "Cache"
  "Code Cache"
  "CachedData"
  "GPUCache"
  "Session Storage"
  "Shared Dictionary"
  "DawnGraphiteCache"
  "DawnWebGPUCache"
  "Crashpad"
  "SharedStorage"
  "Trust Tokens"
  "Trust Tokens-journal"
  "Local Storage"
  "Cookies"
  "Cookies-journal"
  "Dictionaries"
  "Network Persistent State"
  "Preferences"
  "TransportSecurity"
)
for app in "${ELECTRON_APPS[@]}"; do
  for path in "${ELECTRON_RELATIVE_PATHS[@]}"; do
    EXCLUDE+=("$app/$path")
  done
done

# Join it into a string separated by commas
EXCLUDE_STR=$(IFS=,; echo "${EXCLUDE[*]}")
fd --one-file-system --prune --base-directory / --type f --hidden --exclude "{$EXCLUDE_STR}" "$@"
