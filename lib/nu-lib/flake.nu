use std/log

export-env {
  $env.GIT_ROOT = ($env.PWD | git rev-parse --show-toplevel | str trim)
  $env.CURRENT_HOST = (cat /etc/hostname | str trim)
  $env.CURRENT_USER = (whoami | str trim)
}

export def select_host [] {
  let hosts = flake-eval r#'builtins.attrNames flake.nixosConfigurations |> builtins.concatStringsSep " "'#  --raw
    | split words
    | where $it != $env.CURRENT_HOST

  let selected = ["current", ...($hosts)] | input list -f
  if $selected == "current" {
    $env.CURRENT_HOST
  } else {
    $selected
  }
}

export def select_user [] {
  let users = flake-eval r#'builtins.attrNames flake.homeConfigurations |> builtins.concatStringsSep " "'#  --raw
    | split words
    | where $it != $env.CURRENT_USER

  let selected = ["current", ...($users)] | input list -f
  if $selected == "current" {
    $env.CURRENT_USER
  } else {
    $selected
  }
}

export def --wrapped flake-eval [
  expr: string
  ...nix_args: string,
] {

  nix eval --quiet --no-pure-eval ...$nix_args --expr $'
    let
      flake = builtins.getFlake "($env.GIT_ROOT)";
    in ($expr)
  '
}

# Recursively extract all objects with file fields from nested graph structure
export def flatten_graph_recursively [] {
  def extract_objects [input] {
    let type = ($input | describe)

    if ($type | str starts-with "list") or ($type | str starts-with "table") {
      $input | each { |item| extract_objects $item } | flatten
    } else if ($type | str starts-with "record") {
      let result = if ($input | get -o file | default null) != null { [$input] } else { [] }
      let imports_result = if ($input | get -o imports | default null) != null {
        extract_objects ($input.imports)
      } else { [] }
      $result ++ $imports_result
    } else {
      []
    }
  }

  extract_objects $in
}

export def get_output_graph_files [
  identifier: string
  flake_source: string
] {
  let graph_file = (mktemp -t "module-graph.XXXX")

  try {
    run-external "nix" "eval" "--json" $".#($identifier).graph" o> $graph_file
  } catch { |err|
    log error $"Failed to evaluate graph for ($identifier): ($err)"
    exit 1
  }

  let files = open $graph_file
    | from json
    | flatten_graph_recursively
    | where ($it | get -o file | default "" | str starts-with $"($flake_source)/")
    | get file
    | each { |file| $file | str replace $"($flake_source)/" "" }
    | each { |file_path|
      if ($file_path | path type) != "dir" {
        $file_path
      } else {
        let default_nix_path = ([$file_path, "default.nix"] | path join)
        if ($default_nix_path | path exists) {
          $default_nix_path
        } else {
          $file_path
        }
      }
    } | sort | uniq

  rm $graph_file
  $files
}

# Gets some basic flake info
#
# Returns a record like:
# {
#   source_path
#   hash
# }
export def get_flake_info [] {
  let archive_info = try {
    nix flake archive --json | from json
  } catch { |err|
    log error $"Failed to get flake archive info: ($err)"
    exit 1
  }

  let source_path = $archive_info.path
  if ($source_path | is-empty) or ($source_path == "null") {
    log error "Failed to resolve flake source path."
    exit 1
  }

  let hash = $source_path | path basename | str substring 0..11
  if ($hash | is-empty) {
    log error "Failed to extract flake hash."
    exit 1
  }

  { source_path: $source_path, hash: $hash }
}

# Gets the revision and hash of a flake input
#
# Returns a record like:
# {
#   rev
#   hash
# }
export def get_flake_input [
  lock_file: string   # The lock file to read from
  input_name: string  # The name of the input to check for changes.
] {
  jq -r --arg input_name $input_name '
    (.root) as $r
    | (.nodes[$r].inputs[$input_name] // $input_name) as $n0
    | ($n0 | if type=="string" then . else (.[0] // $input_name) end) as $n
    | (.nodes[$n].locked // {})
    | { rev: (.rev // "none"), hash: (.narHash // "none") }
  ' $lock_file e> /dev/null | from json
}

export def has_flake_inputs_changed [
  git_range: string
  input_name: string
] {
  let split_range = $git_range | split row ".."
  let head_commit = $split_range | last
  let prev_commit = $split_range | first

  let root_flake_changed = not (git diff --name-only $git_range -- flake.lock | str trim | is-empty)
  if $root_flake_changed {
    let prev_lock_file = mktemp -t "old-lock.XXXX"
    git show $"($prev_commit):flake.lock" | save -f $prev_lock_file
    let prev_input = get_flake_input $prev_lock_file $input_name
    let curr_input = get_flake_input flake.lock $input_name
    log info $"Previous ($input_name): ($prev_input), Current ($input_name): ($curr_input)"
    if $prev_input.rev != $curr_input.rev {
      log info $"Root flake.nix ($input_name) version changed from [($prev_input.rev)] to [($curr_input.rev)]"
      return true
    }
  }

  return false
}

# Check if a file has changed between git range
export def check_file_changed [
  git_range: string # The git range to check for changes.
  ...files: string
] {
  log info $"Checking files for changes: ($files)"
  let split_range = $git_range | split row ".."
  let head_commit = $split_range | last
  let prev_commit = $split_range | first

  let git_file_diffs = git diff --name-only $git_range -- ...$files | str trim | split row "\n" | where {|f| not ($f | is-empty) }
  if ($git_file_diffs | is-empty) {
    log info "No changes detected in the specified files"
    return false;
  }

  log info $"Git file diffs: ($git_file_diffs)"
  mut changed_files = [ ];
  for file in $git_file_diffs {
    let has_changed = $git_file_diffs | any {|f| $f == $file }
    let old_file = mktemp -t "old-file.XXXX"
    git show $"($prev_commit):($file)" | save -f $old_file

    log info $"Checking differences between ($file) and ($old_file)"
    let old_hash = nix hash file $old_file
    let cur_hash = nix hash file $file

    if $old_hash != $cur_hash {
      log info $"File [($file)] has changed."
      $changed_files = $changed_files | append $file
    }
  }

  return (($changed_files | length) > 0)
}
