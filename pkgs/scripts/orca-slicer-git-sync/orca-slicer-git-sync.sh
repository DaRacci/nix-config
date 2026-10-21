#!/usr/bin/env bash

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: orca-slicer-git-sync <repo-dir> [remote-url]"
  exit 1
fi

repo_dir=$1
remote_url=${2:-}
once_mode=${ORCA_GIT_SYNC_ONCE:-0}
batch_delay=${ORCA_GIT_SYNC_BATCH_DELAY:-2}
repo_retry_interval=${ORCA_GIT_SYNC_REPO_RETRY_INTERVAL:-10}
watch_retry_interval=${ORCA_GIT_SYNC_WATCH_RETRY_INTERVAL:-5}

wait_for_repo_dir() {
  until [ -d "$repo_dir" ]; do
    sleep "$repo_retry_interval"
  done
}

ensure_repo() {
  if [ -d "$repo_dir/.git" ]; then
    return 0
  fi

  echo "Initializing git repository at $repo_dir"
  git -C "$repo_dir" init -q
  git -C "$repo_dir" add -A
  if ! git -C "$repo_dir" diff --cached --quiet 2>/dev/null; then
    git -C "$repo_dir" commit -m "chore: initial commit" -q
    echo "Created initial commit"
  fi
}

ensure_remote() {
  if [ -z "$remote_url" ]; then
    return 0
  fi

  current_remote=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)
  if [ "$current_remote" != "$remote_url" ]; then
    git -C "$repo_dir" remote remove origin 2>/dev/null || true
    git -C "$repo_dir" remote add origin "$remote_url"
    echo "Configured remote: $remote_url"
  fi
}

derive_commit_message() {
  local status=$1
  local line

  while IFS= read -r line; do
    [ -n "$line" ] || continue

    local xy filepath type basename_file name x y
    xy=${line:0:2}
    filepath=${line:3}

    if [[ "$filepath" == *" -> "* ]]; then
      filepath=${filepath##* -> }
    fi

    filepath=${filepath#\"}
    filepath=${filepath%\"}

    if [[ "$filepath" == */* ]]; then
      type=${filepath%%/*}
    else
      type=config
    fi

    basename_file=$(basename "$filepath")
    name=${basename_file%.*}
    x=${xy:0:1}
    y=${xy:1:1}

    if [[ "$xy" == "??" || "$x" == "A" || "$y" == "A" ]]; then
      printf 'feat(%s): added %s\n' "$type" "$name"
    elif [[ "$x" == "D" || "$y" == "D" ]]; then
      printf 'chore(%s): removed %s\n' "$type" "$name"
    else
      printf 'refactor(%s): updated %s\n' "$type" "$name"
    fi
    return 0
  done <<< "$status"

  return 1
}

commit_changes() {
  local status msg

  status=$(git -C "$repo_dir" status --porcelain --untracked-files=all 2>/dev/null) || return 0
  [ -n "$status" ] || return 0

  msg=$(derive_commit_message "$status") || return 0

  echo "Changes detected, preparing commit..."
  git -C "$repo_dir" add -A
  if ! git -C "$repo_dir" diff --cached --quiet 2>/dev/null; then
    git -C "$repo_dir" commit -m "$msg" -q
    echo "Committed: $msg"

    if [ -n "$remote_url" ]; then
      if git -C "$repo_dir" push -q origin HEAD 2>/dev/null; then
        echo "Pushed to remote: $remote_url"
      else
        echo "Warning: Failed to push to remote $remote_url"
      fi
    fi
  fi
}

watch_loop() {
  echo "Starting OrcaSlicer git sync watcher for $repo_dir"

  while true; do
    if inotifywait -r -q \
        -e close_write -e create -e delete -e moved_to -e moved_from \
        --exclude '\.git' \
        "$repo_dir" 2>/dev/null; then
      echo "Filesystem change detected, processing git commit..."
      sleep "$batch_delay"
      commit_changes
    else
      sleep "$watch_retry_interval"
    fi
  done
}

wait_for_repo_dir
ensure_repo
ensure_remote

if [ "$once_mode" = "1" ]; then
  commit_changes
  exit 0
fi

watch_loop
