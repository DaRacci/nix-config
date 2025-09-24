# shellcheck disable=SC2148

# Usage:
#   drive-stats.sh <device>
#     -> Outputs JSON with temperature, available, used, read, write (speeds in bytes/sec)
#
#   drive-stats.sh <variable> <device>
#     -> Outputs just the numeric value (or 'null' if unavailable)
#
#   drive-stats.sh human <device>
#     -> Outputs a human-readable summary table (same metrics, pretty units)
#
# Variables (case-insensitive):
#   temperature   (degrees Celsius)
#   available|avail (bytes)
#   used          (bytes)
#   read|read_speed   (bytes/sec, sampled over 1s)
#   write|write_speed (bytes/sec, sampled over 1s)
#   human|--human|-h (pretty table output; must be first arg)
#
# Notes:
# - Speeds are sampled over ~1 second by reading /sys/block/<dev>/stat.
# - Space metrics come from the mounted filesystem for the given block device (if any).
# - Temperature tries sysfs first, then smartctl if available.
# - If the provided path is a partition (e.g. /dev/nvme0n1p1) stats still work.
# - If something can't be determined, 'null' is returned for that field in JSON mode.
#
# Exit codes:
#   0 success
#   1 usage / argument error
#   2 device not found
#
set -u

print_usage() {
  cat <<'EOF' >&2
Usage:
  drive-stats.sh <device>
  drive-stats.sh <variable> <device>
  drive-stats.sh human <device>

Notes:
  - By default the script prints human-readable output (pretty units).
  - To get raw numeric outputs (bytes or bytes/sec or degrees) set RAW_OUTPUT=1 in the environment.

Examples:
  drive-stats.sh /dev/nvme0n1
  drive-stats.sh temperature /dev/nvme0n1
  drive-stats.sh read /dev/sda
  RAW_OUTPUT=1 drive-stats.sh read /dev/sda

Variables:
  temperature, available (avail), used, read (read_speed), write (write_speed), human

Environment variables:
  SAMPLE_INTERVAL   Sampling duration (seconds) for read/write speed (default 1)
  CACHE_TTL         Cache reuse window (seconds) for speed samples (default 2)
  RAW_OUTPUT        If set (non-empty) the script will output raw numeric values for single-variable calls
                    and will output JSON numeric fields unchanged for device JSON mode.
  DEBUG_DRIVE_STATS Enable debug logging when set (1) or set to 'trace' for shell tracing.

EOF
}

# -------- Helpers --------
debug() {
  if [[ -n "${DEBUG_DRIVE_STATS:-}" ]]; then
    local ts
    ts="$(date +'%Y-%m-%dT%H:%M:%S')"
    echo "[drive-stats][$ts] $*" >&2
  fi
}

# Top-level humanize and formatting helpers (available globally)
# - humanize_bytes  : convert raw bytes to largest unit >= 1 (B, KiB, MiB, GiB, TiB)
# - humanize_rate   : append "/s" to humanized bytes
# - format_or_raw_* : return RAW numeric by default for variable-mode; set HUMAN_OUTPUT=1 to force human strings
humanize_bytes() {
  local v="$1"
  if [[ -z "$v" || "$v" == "null" ]]; then
    printf 'null'
    return
  fi
  # Use awk to pick the largest unit where value >= 1 and format with one decimal when applicable
  awk -v b="$v" 'BEGIN{
    units[0]="B"; units[1]="KiB"; units[2]="MiB"; units[3]="GiB"; units[4]="TiB";
    divisors[0]=1; divisors[1]=1024; divisors[2]=1048576; divisors[3]=1073741824; divisors[4]=1099511627776;
    for(i=4;i>=0;i--){
      d = divisors[i];
      if (d>0 && b/d >= 1) { printf "%.1f %s", b/d, units[i]; exit }
    }
    printf "%d B", b
  }'
}

humanize_rate() {
  local v="$1"
  if [[ -z "$v" || "$v" == "null" ]]; then
    printf 'null'
    return
  fi
  printf '%s/s' "$(humanize_bytes "$v")"
}

# New default behaviour:
# - variable-mode calls use the raw numeric values by default (no humanization).
# - to get human formatted output in variable-mode, set HUMAN_OUTPUT=1 in the environment.
# - RAW_OUTPUT remains supported (explicit raw), but RAW_OUTPUT is not required for raw outputs anymore.
format_or_raw_size() {
  local v="$1"
  if [[ -z "$v" || "$v" == "null" ]]; then
    printf 'null\n'
    return
  fi
  if [[ -n "${HUMAN_OUTPUT:-}" ]]; then
    # Human-friendly representation (e.g. "120.3 GiB")
    printf '%s\n' "$(humanize_bytes "$v")"
  else
    # Default: convert bytes -> gigabytes (decimal GB) and print numeric value only (no unit)
    # Use 1000^3 = 1000000000 as divisor to match decimal gigabyte (GB)
    awk -v b="$v" 'BEGIN{printf "%.3f\n", (b/1000000000)}'
  fi
}

format_or_raw_rate() {
  local v="$1"
  if [[ -z "$v" || "$v" == "null" ]]; then
    printf 'null\n'
    return
  fi
  if [[ -n "${HUMAN_OUTPUT:-}" ]]; then
    # Human-friendly (e.g. "15.2 MiB/s")
    printf '%s\n' "$(humanize_rate "$v")"
  else
    # Default: convert bytes/sec -> megabytes/sec (decimal MB/s) and print numeric value only (no unit)
    # Use 1000^2 = 1000000 as divisor to match decimal megabyte (MB)
    awk -v b="$v" 'BEGIN{printf "%.3f\n", (b/1000000)}'
  fi
}

format_or_raw_temp() {
  local v="$1"
  if [[ -z "$v" || "$v" == "null" ]]; then
    printf 'null\n'
    return
  fi
  if [[ -n "${HUMAN_OUTPUT:-}" ]]; then
    printf '%s\n' "${v} °C"
  else
    # Default: raw numeric temperature (Celsius) with no unit suffix
    printf '%s\n' "$v"
  fi
}

trace_enter() {
  if [[ -n "${DEBUG_DRIVE_STATS:-}" ]]; then
    debug "ENTER $1($2)"
  fi
}

# Enable shell xtrace if DEBUG_DRIVE_STATS=trace (very verbose)
[[ "${DEBUG_DRIVE_STATS:-}" == "trace" ]] && set -x
# Resolve deepest physical (non-mapper) base block device for temperature collection.
# Follows PKNAME chain via lsblk until it can no longer descend (e.g. dm-0 -> nvme0n1).
physical_base_device() {
  trace_enter physical_base_device "$1"
  # Resolve the deepest underlying physical (non-mapper) disk for temperature.
  # Strategy:
  # 1. Work with the original path first (important: /dev/mapper/cryptroot often exposes PKNAME for the partition,
  #    but the resolved /dev/dm-0 may not).
  # 2. Ascend via PKNAME while it changes.
  # 3. If no PKNAME change and device is a dm node, descend to its first slave (partition) then continue ascending.
  # 4. After traversal, strip partition suffix (nvme0n1p2 -> nvme0n1, sda1 -> sda).
  local dev="$1"
  command -v lsblk >/dev/null 2>&1 || return 1

  local orig_path path cur
  orig_path="$dev"
  if [[ -b "$orig_path" ]]; then
    path="$orig_path"
  else
    path="$(readlink -f "$orig_path" 2>/dev/null || true)"
  fi
  [[ -b "$path" ]] || return 1
  cur=$(basename "$path")

  # Helper: attempt to get PKNAME for a path (prefer original path first)
  get_pk() {
    local p="$1"
    local pk
    pk=$(lsblk -no PKNAME "$p" 2>/dev/null | head -n1 || true)
    printf '%s\n' "$pk"
  }

  while true; do
    local pk=""
    # Try PKNAME via current full path (if we still have the original mapper path and it's first iteration)
    if [[ "$path" == "$orig_path" ]]; then
      pk=$(get_pk "$path")
    fi
    # Fallback: PKNAME via /dev/$cur
    if [[ -z "$pk" ]]; then
      pk=$(get_pk "/dev/$cur")
    fi

    if [[ -n "$pk" && "$pk" != "$cur" ]]; then
      cur="$pk"
      path="/dev/$cur"
      continue
    fi

    # If still a device-mapper node (dm-*) or has slaves, descend to first slave (to find partition),
    # then loop again to climb up to its parent disk.
    if [[ "$cur" == dm-* || -d "/sys/block/$cur/slaves" ]]; then
      local slave
      slave=$(find "/sys/block/$cur/slaves" -maxdepth 1 -type l 2>/dev/null | head -n1 | xargs -r basename || true)
      if [[ -n "$slave" && "$slave" != "$cur" ]]; then
        cur="$slave"
        path="/dev/$cur"
        continue
      fi
    fi
    break
  done

  # Normalize to base disk name (remove partition suffix)
  local final
  final=$(block_base "/dev/$cur")
  printf '%s\n' "$final"
}

# Resolve canonical device path (follow symlinks)
canonical_device() {
  local dev="$1"
  # Basic validation
  if [[ ! -e "$dev" ]]; then
    return 1
  fi
  readlink -f -- "$dev"
}

# Extract the block device "basename":
# /dev/nvme0n1p1 -> nvme0n1 (parent); keep both full dev and base for sysfs.
block_base() {
  local devfile="$1"
  local base
  base=$(basename -- "$devfile")
  # For NVMe partitions, names end with 'p<digit>', the parent device lacks the partition number + p.
  # For generic disks (sda1) parent is sda.
  if [[ "$base" =~ ^(nvme[0-9]+n[0-9]+)p[0-9]+$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  elif [[ "$base" =~ ^([a-z]+)[0-9]+$ ]] && [[ -b "/dev/${BASH_REMATCH[1]}" ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "$base"
  fi
}

# Try to get temperature (Celsius, integer)
get_temperature() {
  trace_enter get_temperature "$1"
  debug "Temperature lookup start dev='$1'"
  local dev="$1"
  local base temp_file raw
  # Prefer underlying physical device (important when querying /dev/mapper/* which lacks its own temp)
  local phys
  phys=$(physical_base_device "$dev" 2>/dev/null || true)
  if [[ -n "$phys" ]]; then
    base="$phys"
  else
    base=$(block_base "$dev")
  fi

  # 1. sysfs hwmon under device
  # NVMe path example: /sys/class/block/nvme0n1/device/hwmon/hwmon*/temp1_input
  while IFS= read -r temp_file; do
    if [[ -f "$temp_file" ]]; then
      raw=$(<"$temp_file")
      if [[ "$raw" =~ ^[0-9]+$ ]]; then
        # hwmon temps often in millidegrees
        if (( raw > 1000 )); then
          echo $(( raw / 1000 ))
        else
          echo "$raw"
        fi
        return 0
      fi
    fi
  done < <(find -L "/sys/class/block/$base/device" -maxdepth 4 -type f -name 'temp1_input' 2>/dev/null | head -n1)

  # 2. Generic NVMe temperature file (sometimes available)
  if [[ -f "/sys/class/block/$base/device/temperature" ]]; then
    raw=$(<"/sys/class/block/$base/device/temperature")
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      echo "$raw"
      return 0
    fi
  fi

  # 3. smartctl if installed
  if command -v smartctl >/dev/null 2>&1; then
    # Try JSON first for reliability
    local smart_json
    smart_json=$(smartctl -A -j "$dev" 2>/dev/null || true)
    if [[ -n "$smart_json" ]]; then
      # Look for a field that looks like temperature - different device types differ
      # Grep for "temperature" followed by digits
      local temp_guess
      temp_guess=$(printf '%s\n' "$smart_json" | grep -E '"temperature(_*[^"]*)?"' | grep -Eo '[0-9]+' | head -n1 || true)
      if [[ "$temp_guess" =~ ^[0-9]+$ ]]; then
        echo "$temp_guess"
        return 0
      fi
    fi
    # Fallback plain output pattern
    raw=$(smartctl -A "$dev" 2>/dev/null | awk '/Temperature/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/){print $i; exit}}')
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      echo "$raw"
      return 0
    fi
  fi

  debug "Temperature lookup failed dev='$dev' -> null"
  echo "null"
}

# Get mountpoint if any for the device (preferring an exact match)
get_mountpoint() {
  local dev="$1"
  local mp=""
  # Direct match in /proc/mounts
  mp=$(awk -v d="$dev" '$1==d {print $2; exit}' /proc/mounts)
  if [[ -n "$mp" ]]; then
    printf '%s\n' "$mp"
    return 0
  fi
  # Try lsblk if available (handles partitions)
  if command -v lsblk >/dev/null 2>&1; then
    mp=$(lsblk -no MOUNTPOINT "$dev" 2>/dev/null | head -n1)
    if [[ -n "$mp" ]]; then
      printf '%s\n' "$mp"
      return 0
    fi
  fi
  return 1
}

# Get filesystem usage (used bytes, available bytes)
get_space_usage() {
  local mp="$1"
  # df output: Filesystem 1B-blocks Used Available Use% Mounted on
  df -B1 --output=used,avail "$mp" 2>/dev/null | tail -n1 | awk '{print $1, $2}'
}

# Read sectors stats (returns "read_sectors write_sectors")
get_sectors() {
  trace_enter get_sectors "$1"
  local base="$1"
  # /sys/block/<base>/stat: fields
  # 1 read I/Os
  # 2 read merges
  # 3 read sectors
  # 4 read ticks
  # 5 write I/Os
  # 6 write merges
  # 7 write sectors
  # ...
  local stat_file="/sys/block/$base/stat"
  if [[ ! -r "$stat_file" ]]; then
    echo "0 0"
    return
  fi
  awk '{print $3, $7}' "$stat_file"
}
# Human-readable pretty output (and supporting format helpers)
# These helper functions also support RAW_OUTPUT mode for single-variable calls.
output_human() {
  local dev="$1"
  local base temperature available used read_bps write_bps mp

  # Use global helper functions for formatting:
  # humanize_bytes, humanize_rate, format_or_raw_size, format_or_raw_rate, format_or_raw_temp

  base=$(block_base "$dev")
  temperature=$(get_temperature "$dev")

  if get_mountpoint "$dev" >/dev/null; then
    mp=$(get_mountpoint "$dev")
    read -r used available <<<"$(get_space_usage "$mp")"
    [[ -z "$used" ]] && used="null"
    [[ -z "$available" ]] && available="null"
  else
    used="null"
    available="null"
  fi

  read -r read_bps write_bps < <(get_rw_speed "$base")
  [[ -z "$read_bps" ]] && read_bps="null"
  [[ -z "$write_bps" ]] && write_bps="null"

  printf "Device:        %s\n" "$dev"
  printf "Temperature:   %s\n" "$(format_or_raw_temp "$temperature")"
  printf "Used:          %s\n" "$(format_or_raw_size "$used")"
  printf "Available:     %s\n" "$(format_or_raw_size "$available")"
  printf "Read:          %s\n" "$(format_or_raw_rate "$read_bps")"
  printf "Write:         %s\n" "$(format_or_raw_rate "$write_bps")"
}

# Human-readable output for ZFS datasets / pools
output_human_zfs() {
  local ds="$1"
  debug "ZFS human output for dataset='$ds'"
  local pool="${ds%%/*}"
  local used avail
  if ! read -r used avail < <(zfs list -Hp -o used,avail "$ds" 2>/dev/null); then
    used="null"
    avail="null"
  fi
  # Collect all underlying devices for temperature aggregation
  local dev_lines
  dev_lines=$( (zpool status -LP "$pool" || zpool status -P "$pool") 2>/dev/null | awk '$1 ~ /\/dev\// {print $1}' )
  local first_dev temperature
  first_dev=$(printf '%s\n' "$dev_lines" | head -n1)
  if [[ -n "$first_dev" ]]; then
    temperature=$(get_temperature "$first_dev")
  else
    temperature="null"
  fi
  # Aggregate temps (min/max/avg) if multiple devices
  local tmin=9999 tmax=-9999 tsum=0 tcount=0
  local d tcur
  for d in $dev_lines; do
    tcur=$(get_temperature "$d")
    if [[ "$tcur" =~ ^[0-9]+$ ]]; then
      (( tcur < tmin )) && tmin="$tcur"
      (( tcur > tmax )) && tmax="$tcur"
      tsum=$(( tsum + tcur ))
      tcount=$(( tcount + 1 ))
    fi
  done
  local tavg="null"
  if (( tcount > 0 )); then
    tavg=$(( tsum / tcount ))
  fi

  fmt_bytes() {
    local v="$1"
    if [[ "$v" == "null" ]]; then
      printf 'null'
      return
    fi
    awk -v b="$v" 'function human(x){u[0]="B";u[1]="KiB";u[2]="MiB";u[3]="GiB";u[4]="TiB";for(i=0;i<5 && x>=1024;i++){x/=1024} printf (i? "%.1f %s":"%d %s"), x,u[i]} BEGIN{human(b)}'
  }

  # Speeds (sample once)
  local interval="${SAMPLE_INTERVAL:-1}"
  if ! [[ "$interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v i="$interval" 'BEGIN{exit (i>0)?0:1}'; then
    interval=1
  fi
  local line read_bps write_bps
  if command -v zpool >/dev/null 2>&1; then
    line=$(zpool iostat -Hp "$pool" "$interval" 2 2>/dev/null | tail -n1)
    if [[ -n "$line" ]]; then
      read_bps=$(awk '{print $(NF-1)}' <<<"$line")
      write_bps=$(awk '{print $NF}'    <<<"$line")
    fi
  fi
  [[ -z "$read_bps" ]] && read_bps="null"
  [[ -z "$write_bps" ]] && write_bps="null"

  fmt_rate() {
    local v="$1"
    if [[ "$v" == "null" ]]; then
      printf 'null'
      return
    fi
    printf '%s/s' "$(fmt_bytes "$v")"
  }

  printf "ZFS Dataset:   %s\n" "$ds"
  printf "Pool:          %s\n" "$pool"
  printf "Temperature:   %s\n" "$( [[ "$temperature" == "null" ]] && echo null || echo "${temperature} °C" )"
  if (( tcount > 1 )); then
    printf "Temp (min/max/avg over %d devs): " "$tcount"
    printf "%s / %s / %s\n" \
      "$( [[ "$tmin" == "9999" ]] && echo null || echo "${tmin}°C")" \
      "$( [[ "$tmax" == "-9999" ]] && echo null || echo "${tmax}°C")" \
      "$( [[ "$tavg" == "null" ]] && echo null || echo "${tavg}°C")"
  fi
  printf "Used:          %s\n" "$(fmt_bytes "$used")"
  printf "Available:     %s\n" "$(fmt_bytes "$avail")"
  printf "Read:          %s\n" "$(fmt_rate "$read_bps")"
  printf "Write:         %s\n" "$(fmt_rate "$write_bps")"
  printf "Devices:\n"
  printf "  %s\n" "$(printf '%s\n' "$dev_lines" | sed 's/^/  /')"
}

# Compute read/write bytes per second sampled over ~1s
# Compute read/write bytes per second sampled over configurable interval with caching.
# Environment / flag variables supported (set before calling script or exported by wrapper):
#   SAMPLE_INTERVAL (seconds, default 1)
#   CACHE_TTL       (seconds, default 2)  - how long to reuse a prior speed sample
# Flags could later populate these (not yet parsed as CLI flags here).
get_rw_speed() {
  trace_enter get_rw_speed "$1"
  local base="$1"
  local interval="${SAMPLE_INTERVAL:-1}"
  local cache_ttl="${CACHE_TTL:-2}"

  # Normalise interval (must be positive integer or float > 0)
  if ! [[ "$interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v i="$interval" 'BEGIN{exit (i>0)?0:1}'; then
    debug "Invalid SAMPLE_INTERVAL='${interval}' -> using 1"
    interval=1
  fi
  debug "Sampling interval: ${interval}s (base=${base})"
  # Prepare cache
  local cache_dir="${XDG_CACHE_HOME:-/tmp}/drive-stats"
  mkdir -p "$cache_dir" 2>/dev/null || true
  local cache_file="$cache_dir/${base}_rw_${interval}.cache"
  local now epoch_diff
  now=$(date +%s)

  if [[ -f "$cache_file" ]]; then
    IFS=' ' read -r ts cached_r cached_w < "$cache_file"
    if [[ "$ts" =~ ^[0-9]+$ ]]; then
      epoch_diff=$(( now - ts ))
      if (( epoch_diff < cache_ttl )); then
        debug "Cache hit (${epoch_diff}s old < ${cache_ttl}s TTL) read=${cached_r:-0} write=${cached_w:-0} B/s"
        # Reuse cached sample
        echo "${cached_r:-0} ${cached_w:-0}"
        return 0
      fi
    fi
  fi

  local r1 w1 r2 w2
  read -r r1 w1 < <(get_sectors "$base")
  sleep "$interval"
  read -r r2 w2 < <(get_sectors "$base")
  local dr=$(( r2 - r1 ))
  local dw=$(( w2 - w1 ))
  if (( dr < 0 )); then dr=0; fi
  if (( dw < 0 )); then dw=0; fi

  # sectors are typically 512 bytes (logical sector size)
  local logical=512
  if [[ -r "/sys/block/$base/queue/logical_block_size" ]]; then
    local lsz
    lsz=$(<"/sys/block/$base/queue/logical_block_size")
    if [[ "$lsz" =~ ^[0-9]+$ ]] && (( lsz > 0 )); then
      logical=$lsz
    fi
  fi

  # Convert to bytes per second (adjust if interval != 1)
  # dr/dw counted in sectors during 'interval' seconds.
  # bytes_per_sec = (delta_sectors * sector_size) / interval
  # Use awk for float-safe division then print integer.
  local read_bps write_bps
  read_bps=$(awk -v d="$dr" -v l="$logical" -v i="$interval" 'BEGIN{printf "%.0f", (d*l)/i}')
  write_bps=$(awk -v d="$dw" -v l="$logical" -v i="$interval" 'BEGIN{printf "%.0f", (d*l)/i}')
  debug "Sampled dr=${dr} dw=${dw} sectors (logical=${logical}B, interval=${interval}s) -> read=${read_bps} write=${write_bps} B/s"

  printf '%s %s\n' "$read_bps" "$write_bps" > "$cache_file".tmp 2>/dev/null || true
  printf '%s %s %s\n' "$now" "$read_bps" "$write_bps" > "$cache_file"
  rm -f "$cache_file".tmp 2>/dev/null || true

  echo "$read_bps $write_bps"
}

output_json() {
  trace_enter output_json "$1"
  debug "output_json arg='$1'"
  local dev="$1"

  local is_zfs=0
  local zfs_dataset=""
  # Enhanced ZFS detection:
  # 1. Direct pool/dataset name (zfs list)
  # 2. Pool name only (zpool list)
  # 3. Given a mountpoint path (directory) map to dataset via mountpoint column
  if command -v zfs >/dev/null 2>&1 || command -v zpool >/dev/null 2>&1; then
    debug "ZFS detection phase (arg='$dev')"
    if command -v zfs >/dev/null 2>&1; then
      if zfs list -H -o name "$dev" 2>/dev/null | grep -Fxq "$dev"; then
        zfs_dataset="$dev"
        is_zfs=1
        debug "Detected ZFS dataset by direct name: $dev"
      fi
    fi
    if (( ! is_zfs )) && command -v zpool >/dev/null 2>&1; then
      if zpool list -H -o name 2>/dev/null | grep -Fxq "$dev"; then
        zfs_dataset="$dev"
        is_zfs=1
        debug "Detected ZFS pool name: $dev"
      fi
    fi
    # If argument is a directory (mountpoint), try to map to dataset name
    if (( ! is_zfs )) && [[ -d "$dev" ]] && command -v zfs >/dev/null 2>&1; then
      # Match exact mountpoint (second column)
      zfs_dataset=$(zfs list -H -o name,mountpoint 2>/dev/null | awk -v mp="$dev" '$2==mp {print $1; exit}')
      if [[ -n "$zfs_dataset" ]]; then
        is_zfs=1
        debug "Mapped mountpoint '$dev' to ZFS dataset '$zfs_dataset'"
      fi
    fi
  fi
  # If we mapped a mountpoint, work with dataset name
  if (( is_zfs )) && [[ -n "$zfs_dataset" ]]; then
    dev="$zfs_dataset"
  fi

  if (( is_zfs )); then
    local pool="${dev%%/*}"
    local used available
    # Use correct column name 'avail' (short form) for available bytes
    debug "ZFS space query: zfs list -Hp -o used,avail '$dev'"
    if read -r used available < <(zfs list -Hp -o used,avail "$dev" 2>/dev/null); then
      : # values captured
    else
      used="null"
      available="null"
    fi

    # Temperature: pick first underlying /dev path from zpool status
    local temp_dev temperature
    # Try -LP (logical + physical paths) then fallback to -P
    debug "ZFS temperature: scanning zpool status for pool '$pool'"
    temp_dev=$( (zpool status -LP "$pool" 2>/dev/null || zpool status -P "$pool" 2>/dev/null) | awk '$1 ~ /\/dev\// {print $1; exit}')
    if [[ -n "$temp_dev" ]]; then
      temperature=$(get_temperature "$temp_dev")
    else
      temperature="null"
    fi

    # Speeds: sample via zpool iostat (bandwidth columns = bytes/s with -p)
    local interval="${SAMPLE_INTERVAL:-1}"
    if ! [[ "$interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v i="$interval" 'BEGIN{exit (i>0)?0:1}'; then
      interval=1
    fi
    local line read_bps write_bps
    if command -v zpool >/dev/null 2>&1; then
      # Take second sample to get interval-based stats
      debug "ZFS iostat sampling pool='$pool' interval=${interval}s"
      line=$(zpool iostat -Hp "$pool" "$interval" 2 2>/dev/null | tail -n1)
      if [[ -n "$line" ]]; then
        # Expected columns: name alloc free ops_read ops_write bw_read bw_write
        read_bps=$(awk '{print $(NF-1)}' <<<"$line")
        write_bps=$(awk '{print $NF}' <<<"$line")
      fi
    fi
    [[ -z "$read_bps" ]] && read_bps="null"
    [[ -z "$write_bps" ]] && write_bps="null"

    cat <<EOF
{
  "device": "$(printf '%q' "$dev")",
  "temperature": $temperature,
  "available": $available,
  "used": $used,
  "read": $read_bps,
  "write": $write_bps,
  "zfs": true,
  "pool": "$(printf '%s' "$pool")",
  "physical_device": "$(printf '%s' "$temp_dev")"
}
EOF
    return
  fi

  # Non-ZFS (block device) path
  local base
  base=$(block_base "$dev")

  local temperature available used read_bps write_bps
  temperature=$(get_temperature "$dev")

  local mp
  if get_mountpoint "$dev" >/dev/null; then
    mp=$(get_mountpoint "$dev")
    read -r used available <<<"$(get_space_usage "$mp")"
    [[ -z "$used" ]] && used="null"
    [[ -z "$available" ]] && available="null"
  else
    used="null"
    available="null"
  fi

  read -r read_bps write_bps < <(get_rw_speed "$base")
  [[ -z "$read_bps" ]] && read_bps="null"
  [[ -z "$write_bps" ]] && write_bps="null"

  cat <<EOF
{
  "device": "$(printf '%q' "$dev")",
  "temperature": $temperature,
  "available": $available,
  "used": $used,
  "read": $read_bps,
  "write": $write_bps
}
EOF
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# -------- Main --------

if (( $# == 0 )); then
  print_usage
  exit 1
fi

if (( $# == 1 )); then
  debug "MAIN one-arg path: raw='$1'"
  input_device="$1"
  debug "Single-arg invocation: '$input_device'"
  # Try block device canonicalisation only if it looks like a /dev path
  if [[ "$input_device" == /dev/* ]]; then
    if device=$(canonical_device "$input_device" 2>/dev/null); then
      debug "Treating as block device: $device"
      output_json "$device"
      exit 0
    fi
  fi
  # ZFS detection (pool/dataset name or mountpoint)
  if (command -v zfs >/dev/null 2>&1 || command -v zpool >/dev/null 2>&1); then
    # Direct dataset / pool name
    if command -v zfs >/dev/null 2>&1 && zfs list -H -o name "$input_device" 2>/dev/null | grep -Fxq "$input_device"; then
      debug "Detected ZFS dataset by name: $input_device"
      output_json "$input_device"
      exit 0
    fi
    if command -v zpool >/dev/null 2>&1 && zpool list -H -o name 2>/dev/null | grep -Fxq "$input_device"; then
      debug "Detected ZFS pool by name: $input_device"
      output_json "$input_device"
      exit 0
    fi
    # Mountpoint mapping (directory path)
    if [[ -d "$input_device" ]] && command -v zfs >/dev/null 2>&1; then
      mp_ds=$(zfs list -H -o name,mountpoint 2>/dev/null | awk -v mp="$input_device" '$2==mp {print $1; exit}')
      if [[ -n "$mp_ds" ]]; then
        debug "Mapped mountpoint '$input_device' to dataset '$mp_ds'"
        output_json "$mp_ds"
        exit 0
      fi
    fi
  fi
  echo "Error: device or ZFS dataset/mountpoint '$input_device' not found" >&2
  exit 2
fi

if (( $# == 2 )); then
  debug "MAIN two-arg path: var='$1' target='$2'"
  var=$(to_lower "$1")
  orig_target="$2"
  device="$orig_target"

  # Attempt canonicalization only for block devices (avoid wiping ZFS dataset names)
  if [[ "$device" == /dev/* ]]; then
    if canonical_device_path=$(canonical_device "$device" 2>/dev/null); then
      debug "Canonicalized block device '$device' -> '$canonical_device_path'"
      device="$canonical_device_path"
    fi
  fi

  # ZFS detection (dataset or pool) for two-arg mode
  local_is_zfs=0
  if command -v zfs >/dev/null 2>&1 || command -v zpool >/dev/null 2>&1; then
    if command -v zfs >/dev/null 2>&1 && zfs list -H -o name "$orig_target" 2>/dev/null | grep -Fxq "$orig_target"; then
      local_is_zfs=1
      device="$orig_target"
      debug "Two-arg: detected ZFS dataset '$device'"
    elif command -v zpool >/dev/null 2>&1 && zpool list -H -o name 2>/dev/null | grep -Fxq "$orig_target"; then
      local_is_zfs=1
      device="$orig_target"
      debug "Two-arg: detected ZFS pool '$device'"
    fi
  fi

  if (( local_is_zfs )); then
    pool="${device%%/*}"
    debug "ZFS two-arg mode: dataset='$device' var='$var'"
    case "$var" in
      human|--human|-h)
        output_human_zfs "$device"
        ;;
      temperature)
        temp_dev=$( (zpool status -LP "$pool" 2>/dev/null || zpool status -P "$pool" 2>/dev/null) | awk '$1 ~ /\/dev\// {print $1; exit}')
        if [[ -n "$temp_dev" ]]; then
          temp_val=$(get_temperature "$temp_dev")
          # get_temperature prints the value; output raw numeric temperature (no unit) for variable mode
          printf '%s\n' "$temp_val"
        else
          echo "null"
        fi
        ;;
      available|avail)
        if read -r _used _avail < <(zfs list -Hp -o used,avail "$device" 2>/dev/null); then
          format_or_raw_size "${_avail:-null}"
        else
          echo "null"
        fi
        ;;
      used)
        if read -r _used _avail < <(zfs list -Hp -o used,avail "$device" 2>/dev/null); then
          format_or_raw_size "${_used:-null}"
        else
          echo "null"
        fi
        ;;
      read|read_speed|write|write_speed)
        interval="${SAMPLE_INTERVAL:-1}"
        if ! [[ "$interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v i="$interval" 'BEGIN{exit (i>0)?0:1}'; then
          interval=1
        fi
        line=$(zpool iostat -Hp "$pool" "$interval" 2 2>/dev/null | tail -n1)
        if [[ -n "$line" ]]; then
          r_bps=$(awk '{print $(NF-1)}' <<<"$line")
          w_bps=$(awk '{print $NF}'    <<<"$line")
        fi
        [[ -z "$r_bps" ]] && r_bps="null"
        [[ -z "$w_bps" ]] && w_bps="null"
        if [[ "$var" =~ ^read ]]; then
          format_or_raw_rate "$r_bps"
        else
          format_or_raw_rate "$w_bps"
        fi
        ;;
      *)
        echo "Error: unknown variable '$1' (ZFS mode)" >&2
        print_usage
        exit 1
        ;;
    esac
    exit 0
  fi

  base=$(block_base "$device")

  case "$var" in
    human|--human|-h)
      output_human "$device"
      ;;
    temperature)
      temp_val=$(get_temperature "$device")
      # get_temperature prints value; output raw numeric temperature (no unit) for variable mode
      printf '%s\n' "$temp_val"
      ;;
    available|avail)
      if mp=$(get_mountpoint "$device"); then
        read -r _used _avail <<<"$(get_space_usage "$mp")"
        format_or_raw_size "${_avail:-null}"
      else
        echo "null"
      fi
      ;;
    used)
      if mp=$(get_mountpoint "$device"); then
        read -r _used _avail <<<"$(get_space_usage "$mp")"
        format_or_raw_size "${_used:-null}"
      else
        echo "null"
      fi
      ;;
    read|read_speed)
      read -r r_bps _w_bps < <(get_rw_speed "$base")
      format_or_raw_rate "${r_bps:-null}"
      ;;
    write|write_speed)
      read -r _r_bps w_bps < <(get_rw_speed "$base")
      format_or_raw_rate "${w_bps:-null}"
      ;;
    *)
      echo "Error: unknown variable '$1'" >&2
      print_usage
      exit 1
      ;;
  esac
  exit 0
fi

print_usage
exit 1
