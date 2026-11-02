#!/usr/bin/env bash

set -euo pipefail

CONFIG_PATH_DEFAULT="${XDG_CONFIG_HOME:-$HOME/.config}/list-ephemeral/config.json"
TRACE_TIMEOUT_DEFAULT=30

print_usage() {
  cat <<'EOF' >&2
Usage:
  list-ephemeral                # open TUI (default)
  list-ephemeral tui            # open TUI
  list-ephemeral list [fd args] # list candidates
  list-ephemeral trace -- <cmd> [args...]

Environment:
  LIST_EPHEMERAL_CONFIG   Override config path (default: $XDG_CONFIG_HOME/list-ephemeral/config.json)
  LIST_EPHEMERAL_TIMEOUT  Trace timeout in seconds (default: 30)
EOF
}

die() {
  echo "list-ephemeral: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"
}

config_path() {
  echo "${LIST_EPHEMERAL_CONFIG:-$CONFIG_PATH_DEFAULT}"
}

load_config() {
  local path
  path="$(config_path)"
  if [[ ! -f "$path" ]]; then
    return 1
  fi
  echo "$path"
}

config_value() {
  local jq_expr="$1"
  local path
  path="$(load_config)" || return 1
  jq -r "$jq_expr" "$path"
}

have_config() {
  local path
  path="$(config_path)"
  [[ -f "$path" ]]
}

ensure_config_or_warn() {
  if ! have_config; then
    echo "list-ephemeral: config not found at $(config_path)" >&2
    echo "list-ephemeral: enable programs.list-ephemeral in Home Manager to generate it" >&2
  fi
}

merge_excludes() {
  if ! have_config; then
    return 0
  fi
  local excludes
  excludes=$(jq -r '[.excludes[], .extraExcludes[]] | unique | .[]' "$(config_path)" 2>/dev/null || true)
  if [[ -n "$excludes" ]]; then
    printf '%s\n' "$excludes"
  fi
}

merge_includes() {
  if ! have_config; then
    return 0
  fi
  local includes
  includes=$(jq -r '.extraIncludes[]?' "$(config_path)" 2>/dev/null || true)
  if [[ -n "$includes" ]]; then
    printf '%s\n' "$includes"
  fi
}

persisted_paths() {
  if ! have_config; then
    return 0
  fi
  jq -r '[.persistedFiles[], .persistedDirs[]] | .[]' "$(config_path)" 2>/dev/null || true
}

persisted_files() {
  if ! have_config; then
    return 0
  fi
  jq -r '.persistedFiles[]?' "$(config_path)" 2>/dev/null || true
}

persisted_dirs() {
  if ! have_config; then
    return 0
  fi
  jq -r '.persistedDirs[]?' "$(config_path)" 2>/dev/null || true
}

program_list() {
  if ! have_config; then
    return 0
  fi
  jq -r '.programs[]' "$(config_path)" 2>/dev/null || true
}

home_dir() {
  if have_config; then
    config_value '.homeDir'
  else
    echo "$HOME"
  fi
}

fd_exclude_args() {
  local excludes
  excludes=$(merge_excludes || true)
  if [[ -z "$excludes" ]]; then
    return 0
  fi
  local IFS=$'\n'
  for pattern in $excludes; do
    printf -- '--exclude=%s\n' "$pattern"
  done
}

candidate_list() {
  local -a fd_args
  mapfile -t fd_args < <(fd_exclude_args)
  fd --one-file-system --prune --base-directory / --hidden --type f --type f "${fd_args[@]}" "$@" | filter_persisted | sort -u
  local includes
  includes=$(merge_includes || true)
  if [[ -n "$includes" ]]; then
    local home
    home="$(home_dir)"
    local home_rel
    home_rel="${home#/}"
    while IFS= read -r include; do
      [[ -z "$include" ]] && continue
      if [[ "$include" == /* ]]; then
        printf '%s\n' "$include"
      else
        printf '%s\n' "${home_rel}/${include}"
      fi
    done <<<"$includes"
  fi
}


fzf_select() {
  local program_file="$TMPDIR/program_filter"
  local candidates_file="$TMPDIR/candidates"
  local reload_script="$TMPDIR/reload.sh"
  local pick_script="$TMPDIR/pick_program.sh"
  local clear_script="$TMPDIR/clear_filter.sh"
  local cfg
  cfg="$(config_path)"

  echo "" > "$program_file"
  cat > "$candidates_file"

  cat > "$reload_script" <<RELOAD
#!/usr/bin/env bash
pf=\$(cat "$program_file")
if [ -n "\$pf" ]; then
  grep -iF "\$pf" "$candidates_file"
else
  cat "$candidates_file"
fi
RELOAD
  chmod +x "$reload_script"

  cat > "$pick_script" <<PICK
#!/usr/bin/env bash
prog=\$(jq -r ".programs[]" "$cfg" 2>/dev/null | gum choose --limit 1 --header "Pick program filter (Esc to clear)" --cursor "▶" 2>/dev/tty || true)
printf '%s' "\$prog" > "$program_file"
PICK
  chmod +x "$pick_script"

  cat > "$clear_script" <<CLEAR
#!/usr/bin/env bash
printf '' > "$program_file"
CLEAR
  chmod +x "$clear_script"

  fzf \
    --multi \
    --disabled \
    --prompt="Browse > " \
    --height=80% \
    --border \
    --info=inline \
    --header=$'/ search │ Esc exit search │ ctrl-p program filter │ ctrl-x clear filter │ Space select │ Ctrl-A all │ Enter confirm' \
    --bind="/:change-prompt(Search > )+enable-search" \
    --bind="esc:change-prompt(Browse > )+disable-search+clear-query" \
    --bind="ctrl-p:execute($pick_script)+reload($reload_script)" \
    --bind="ctrl-x:execute-silent($clear_script)+reload($reload_script)" \
    --bind="space:toggle+down" \
    --bind="ctrl-a:select-all" \
    --bind="ctrl-d:deselect-all" \
    < <("$reload_script")
}

_is_persisted() {
  local normalized="${1%/}"

  local pf
  for pf in "${_PERSISTED_FILES[@]}"; do
    [[ -z "$pf" ]] && continue
    [[ "$normalized" == "${pf%/}" ]] && return 0
  done

  local pd
  for pd in "${_PERSISTED_DIRS[@]}"; do
    [[ -z "$pd" ]] && continue
    local pn="${pd%/}"
    [[ "$normalized" == "$pn" || "$normalized" == "$pn"/* ]] && return 0
  done

  return 1
}

filter_persisted() {
  if ! have_config; then
    cat
    return 0
  fi

  local -a _PERSISTED_FILES _PERSISTED_DIRS
  mapfile -t _PERSISTED_FILES < <(persisted_files)
  mapfile -t _PERSISTED_DIRS < <(persisted_dirs)

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    [[ "$path" == /nix/store/* ]] && continue
    local full_path
    if [[ "$path" != /* ]]; then
      full_path="/$path"
    else
      full_path="$path"
    fi
    if _is_persisted "$full_path"; then
      continue
    fi
    printf '%s\n' "$path"
  done
}

classify_paths() {
  local home
  home="$(home_dir)"
  local home_prefix="$home/"
  local hm_files=()
  local hm_dirs=()
  local host_files=()
  local host_dirs=()
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local full_path
    if [[ "$path" != /* ]]; then
      full_path="/$path"
    else
      full_path="$path"
    fi
    if [[ "$full_path" == "$home_prefix"* ]]; then
      local rel="${full_path#"$home_prefix"}"
      if [[ -d "$full_path" ]]; then
        hm_dirs+=("$rel")
      else
        hm_files+=("$rel")
      fi
    else
      if [[ -d "$full_path" ]]; then
        host_dirs+=("$full_path")
      else
        host_files+=("$full_path")
      fi
    fi
  done

  printf '%s\n' "${hm_files[@]}" >"$TMPDIR/hm_files"
  printf '%s\n' "${hm_dirs[@]}" >"$TMPDIR/hm_dirs"
  printf '%s\n' "${host_files[@]}" >"$TMPDIR/host_files"
  printf '%s\n' "${host_dirs[@]}" >"$TMPDIR/host_dirs"
}

format_list() {
  local indent="$1"
  local -a items=()
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    items+=("$item")
  done
  if (( ${#items[@]} > 0 )); then
    local -a unique_items=()
    mapfile -t unique_items < <(printf '%s\n' "${items[@]}" | sort -u)
    items=("${unique_items[@]}")
  fi
  if (( ${#items[@]} == 0 )); then
    echo "${indent}[]"
    return 0
  fi
  echo "${indent}["
  for item in "${items[@]}"; do
    printf '%s"%s"\n' "${indent}  " "$item"
  done
  echo "${indent}]"
}

generate_snippet() {
  local snippet=""
  local hm_files hm_dirs host_files host_dirs
  hm_files=$(<"$TMPDIR/hm_files")
  hm_dirs=$(<"$TMPDIR/hm_dirs")
  host_files=$(<"$TMPDIR/host_files")
  host_dirs=$(<"$TMPDIR/host_dirs")

  if [[ -n "$hm_files" || -n "$hm_dirs" ]]; then
    snippet+=$'user.persistence = {\n'
    snippet+=$'  files = \n'
    snippet+=$(printf '%s\n' "$hm_files" | format_list "  ")
    snippet+=$';\n'
    snippet+=$'  directories = \n'
    snippet+=$(printf '%s\n' "$hm_dirs" | format_list "  ")
    snippet+=$';\n'
    snippet+=$'};\n\n'
  fi

  if [[ -n "$host_files" || -n "$host_dirs" ]]; then
    snippet+=$'host.persistence = {\n'
    snippet+=$'  files = \n'
    snippet+=$(printf '%s\n' "$host_files" | format_list "  ")
    snippet+=$';\n'
    snippet+=$'  directories = \n'
    snippet+=$(printf '%s\n' "$host_dirs" | format_list "  ")
    snippet+=$';\n'
    snippet+=$'};\n'
  fi

  printf '%s' "$snippet"
}

copy_to_clipboard() {
  local snippet="$1"
  printf '%s' "$snippet" | wl-copy
}

show_preview() {
  local snippet="$1"
  gum style --border normal --padding "1 2" --margin "1 0" --foreground 10 --bold "Snippet copied to clipboard" >&2
  gum pager <<<"$snippet"
}

run_tui() {
  ensure_config_or_warn
  local candidates
  if [[ -t 0 ]]; then
    candidates=$(candidate_list)
  else
    candidates=$(cat)
  fi
  if [[ -z "$candidates" ]]; then
    echo "list-ephemeral: no candidates found" >&2
    return 0
  fi
  local selected
  selected=$(printf '%s\n' "$candidates" | fzf_select || true)
  if [[ -z "$selected" ]]; then
    echo "list-ephemeral: no selection" >&2
    return 0
  fi
  classify_paths <<<"$selected"
  local snippet
  snippet=$(generate_snippet)
  if [[ -z "$snippet" ]]; then
    echo "list-ephemeral: no snippet generated" >&2
    return 0
  fi
  copy_to_clipboard "$snippet"
  show_preview "$snippet"
}

list_candidates() {
  ensure_config_or_warn
  candidate_list "$@"
}

trace_candidates() {
  ensure_config_or_warn
  local tmpdir
  tmpdir=$(mktemp -d)
  local timeout
  timeout="${LIST_EPHEMERAL_TIMEOUT:-$TRACE_TIMEOUT_DEFAULT}"
  if ! have_config; then
    die "trace requires programs.list-ephemeral to be enabled (missing config)"
  fi
  if (( $# == 0 )); then
    die "trace requires a command, use: list-ephemeral trace -- <cmd> [args...]"
  fi
  if ! timeout --preserve-status "$timeout" strace -ff -e trace=file -o "$tmpdir/trace" -- "$@"; then
    echo "list-ephemeral: strace failed or timed out" >&2
  fi

  local paths
  paths=$(grep -hoE '"/[^\"]+"' "$tmpdir"/trace* 2>/dev/null | tr -d '"' | sort -u || true)

  rm -rf "$tmpdir"

  if [[ -z "$paths" ]]; then
    echo "list-ephemeral: no paths captured" >&2
    return 0
  fi

  local -a _PERSISTED_FILES _PERSISTED_DIRS
  mapfile -t _PERSISTED_FILES < <(persisted_files)
  mapfile -t _PERSISTED_DIRS < <(persisted_dirs)

  local filtered=()
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    [[ "$path" == /nix/store/* ]] && continue
    if _is_persisted "$path"; then
      continue
    fi
    filtered+=("$path")
  done <<<"$paths"

  if (( ${#filtered[@]} == 0 )); then
    echo "list-ephemeral: no ephemeral paths found" >&2
    return 0
  fi

  printf '%s\n' "${filtered[@]}" | run_tui
}

main() {
  require_cmd fd
  require_cmd fzf
  require_cmd gum
  require_cmd jq
  require_cmd wl-copy
  require_cmd strace

  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  if (( $# == 0 )); then
    run_tui
    return 0
  fi

  case "$1" in
    tui)
      shift
      run_tui
      ;;
    list)
      shift
      list_candidates "$@"
      ;;
    trace)
      shift
      if [[ "$1" == "--" ]]; then
        shift
      fi
      trace_candidates "$@"
      ;;
    -h|--help)
      print_usage
      ;;
    *)
      run_tui
      ;;
  esac
}

main "$@"
