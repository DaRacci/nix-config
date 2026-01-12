# shellcheck disable=SC2148

# Action delay (seconds) to prevent janky toggling
DISABLE_DELAY=3

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/gamemode-watcher-state"
PENDING_PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/gamemode-watcher-pending"

is_game_window() {
  local window_info class title workspace workspace_id workspace_name
  window_info="$1"

  class=$(echo "$window_info" | jq -r '.class // ""')
  title=$(echo "$window_info" | jq -r '.title // ""')
  workspace=$(echo "$window_info" | jq -r '.workspace // ""')
  workspace_id=$(echo "$workspace" | jq -r '.id // ""')
  workspace_name=$(echo "$workspace" | jq -r '.name // ""')

  if [[ "$workspace_id" == "8" ]] || \
    [[ "$workspace_name" == "Gaming" ]] || \
    [[ "$class" == "gamescope" ]] || \
    [[ "$class" =~ ^steam_app_ ]] || \
    [[ "$class" == "osu!" ]] || \
    [[ "$title" == "osu!" ]]; then
    return 0
  fi
  return 1
}

enable_gamemode() {
  if [[ ! -f "$STATE_FILE" ]] || [[ "$(cat "$STATE_FILE")" != "enabled" ]]; then
    echo "Enabling game mode"
    caelestia shell gameMode enable
    hyprctl keyword plugin:dynamic-cursors:shake:enabled false
    echo "enabled" > "$STATE_FILE"
  fi
}

disable_gamemode() {
  if [[ ! -f "$STATE_FILE" ]] || [[ "$(cat "$STATE_FILE")" != "disabled" ]]; then
    echo "Disabling game mode"
    caelestia shell gameMode disable
    hyprctl keyword plugin:dynamic-cursors:shake:enabled true
    echo "disabled" > "$STATE_FILE"
  fi
}

cancel_pending_action() {
  local target_mode pending_pid pending_mode
  target_mode="${1:-}"

  [[ -f "$PENDING_PID_FILE" ]] || return 0

  # Stored format: "<pid> <mode>"
  read -r pending_pid pending_mode < "$PENDING_PID_FILE"

  # Only cancel when mode matches if a target mode was requested
  if [[ -n "$target_mode" ]] && [[ "$pending_mode" != "$target_mode" ]]; then
    return 0
  fi

  if [[ -n "$pending_pid" ]] && kill -0 "$pending_pid" 2>/dev/null; then
    kill "$pending_pid" 2>/dev/null || true
  fi

  rm -f "$PENDING_PID_FILE"
}

schedule_action() {
  local mode;
  mode="$1"

  cancel_pending_action
  (
    sleep "$DISABLE_DELAY"

    # Re-check current window before disabling
    local window_info
    window_info=$(hyprctl activewindow -j)

    case "$mode" in
      enable)
        if is_game_window "$window_info"; then
          enable_gamemode
        fi
      ;;
      disable)
        if ! is_game_window "$window_info"; then
          disable_gamemode
        fi
      ;;
    esac

    rm -f "$PENDING_PID_FILE"
  ) &

  echo $! > "$PENDING_PID_FILE"
}

handle_focus_change() {
  local window_info
  window_info="$1"

  if is_game_window "$window_info"; then
    cancel_pending_action "disable"
    schedule_action "enable"
  else
    cancel_pending_action "enable"
    schedule_action "disable"
  fi
}

parse_line() {
  local line window_address clients window_info

  line="$1"
  window_address="${line#*>>}"

  clients=$(hyprctl clients -j)
  window_info=$(echo "$clients" | jq -r ".[] | select(.address == \"0x$window_address\")")
  echo "$window_info"
}

handle_focus_change "$(hyprctl activewindow -j)"

SOCKET_PATH="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do
  case "$line" in
    activewindowv2\>*)
      window_info=$(parse_line "$line")
      handle_focus_change "$window_info"
      ;;
  esac
done
