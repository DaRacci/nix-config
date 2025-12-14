#!/usr/bin/env -S nix shell nixpkgs#nushell --command nu

use std/log

# Detect which machines are affected by file changes
def main [
  --range: string # Git range to check
  --json (-j) # Output JSON format
  ...files: string # Specific files to check
] {
  $env.NU_LOG_FORMAT = "%ANSI_START%%LEVEL%|%MSG%%ANSI_STOP%"
  if $json { log set-level 61 }

  log info "Initializing affected machines detection..."

  let cache_dir = ".cache/machine-graphs"
  mkdir $cache_dir

  let flake_info = get_flake_info
  let cache_key = $flake_info.hash

  log info $"Flake source path: ($flake_info.source_path)"
  log info $"Cache key: ($cache_key)"

  mut dirty_files = $files
  if not ($range | is-empty) {
    $dirty_files = $dirty_files | append (get_dirty_files_from_git_range $range)
  }
  if ($dirty_files | is-empty) {
    $dirty_files = get_dirty_files_from_git
  }

  if ($dirty_files | is-empty) {
    log info "No dirty files to process."
    return
  }

  log info "Files to check:"
  $dirty_files | each { |f| log info $"  ($f)" }

  let machines = get_nixos_machines
  if ($machines | is-empty) {
    log error "No nixosConfigurations found in flake."
    exit 1
  }

  log info $"Found machines: ($machines | str join ', ')"

  let user_files = compute_user_graphs $cache_key $cache_dir $flake_info.source_path
  let machine_files = compute_machine_graphs $machines $user_files $cache_key $cache_dir $flake_info.source_path
  let results = check_affected_machines $dirty_files $machine_files

  output_results $results $dirty_files $json
}

def get_flake_info [] {
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

# Recursively extract all objects with file fields from nested graph structure
def flatten_graph_recursively [] {
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

def get_dirty_files_from_git [] {
  try {
    git status --porcelain
    | lines
    | where ($it | str length) > 0
    | each { |line|
        # Parse git status line format: "XY filename"
        # Where X and Y are status codes, skip if deletion
        if not ($line | str starts-with "D ") and not ($line | str starts-with " D") {
          $line | str substring 3..
        }
      }
    | where ($it != null)
    | sort
    | uniq
  } catch { |err|
    log warning $"Failed to get dirty files from git: ($err)"
    exit 1
  }
}

def get_dirty_files_from_git_range [range: string] {
  try {
    git diff --name-only $range
    | lines
    | where ($it | str length) > 0
    | sort
    | uniq
  } catch { |err|
    log warning $"Failed to get dirty files from git range ($range): ($err)"
    exit 1
  }
}

def get_nixos_machines [] {
  try {
    nix eval --json .#nixosConfigurations --apply 'builtins.attrNames' | from json
  } catch { |err|
    log error $"Failed to get nixosConfigurations: ($err)"
    exit 1
  }
}

def compute_machine_graphs [
  machines: list<string>
  user_files: record
  cache_key: string
  cache_dir: string
  flake_source: string
] {
  log info "Computing and caching file graphs for all machines..."

  mut machine_files = {}

  for machine in $machines {
    let cache_file = $"($cache_dir)/($machine)-($cache_key)"

    if ($cache_file | path exists) {
      log info $"  Loading cached graph for ($machine)..."
      let cached_content = open $cache_file | from json
      $machine_files = ($machine_files | insert $machine $cached_content)
      log info $"    Loaded ($cached_content | length) files from cache"
      continue
    }

    log info $"  Computing graph for ($machine)..."
    mut files: list<string> = collect_files_from_graph $machine $".#nixosConfigurations.($machine).graph" $flake_source

    let home_configurations = nix eval --json $".#homeConfigurations" --apply 'builtins.attrNames' | from json
    let users = nix eval --json $".#nixosConfigurations.($machine).config.users.users" --apply 'builtins.attrNames' | from json
    for user in $users {
      if not ($user in $home_configurations) { continue }

      let home_files: list<string> = $user_files | get -o $user | default []
      log info $"    Merging home configuration files for user ($user): ($home_files | length) files"

      $files = $files | append $home_files
    }

    $files | to json | save $cache_file
    $machine_files = ($machine_files | insert $machine $files)
    log info $"    Computed and cached ($files | length) files"

    # Clean up old cache files for this machine
    try {
      ls $cache_dir
      | where name =~ $"($machine)-.*"
      | where name != $cache_file
      | get name
      | each { |old_file| rm $old_file }
    }
  }

  $machine_files
}

def compute_user_graphs [
  cache_key: string
  cache_dir: string
  flake_source: string
] {
  log info "Computing and caching file graphs for all home configurations..."

  mut user_files = {}

  let home_configurations: list<string> = nix eval --json .#homeConfigurations --apply 'builtins.attrNames' | from json
  for user in $home_configurations {
    let cache_file = $"($cache_dir)/home-($user)-($cache_key)"

    if ($cache_file | path exists) {
      log info $"  Loading cached graph for home configuration ($user)..."
      let cached_content = open $cache_file | from json
      $user_files = ($user_files | insert $user $cached_content)
      log info $"    Loaded ($cached_content | length) files from cache"
      continue
    }

    log info $"  Computing graph for home configuration ($user)..."
    let files: list<string> = collect_files_from_graph $user $".#homeConfigurations.($user).graph" $flake_source
    $files | to json | save $cache_file
    $user_files = ($user_files | insert $user $files)
    log info $"    Computed and cached ($files | length) files"

    # Clean up old cache files for this user
    try {
      ls $cache_dir
      | where name =~ $"home-($user)-.*"
      | where name != $cache_file
      | get name
      | each { |old_file| rm $old_file }
    }
  }

  $user_files
}

def collect_files_from_graph [
  identifier: string
  eval_str: string
  flake_source: string
] {
  let raw_files = try {
    # Write graph to temp file to avoid nix eval piping issues in nushell
    let graph_file = $"/tmp/graph-($identifier).json"
    run-external "nix" "eval" "--json" $eval_str o> $graph_file e> /dev/null

    let files = open $graph_file
    | flatten_graph_recursively
    | where ($it | get -o file | default "" | str starts-with $"($flake_source)/")
    | get file
    | each { |file| $file | str replace $"($flake_source)/" "" }
    | sort
    | uniq

    rm $graph_file
    $files
  } catch { |err|
    log error $"Failed to get graph for ($identifier): ($err)"
    exit 1
  }

  # Handle directory imports with default.nix
  let flattened_files = $raw_files | each { |file_path|
    if ($file_path | path type) != "dir" {
      $file_path
    } else {
      let default_nix_path = $"($file_path | path)/default.nix"
      if ($default_nix_path | path exists) {
        ($file_path | append $default_nix_path)
      }
    }
  } | sort | uniq

  $flattened_files
}

def check_affected_machines [
  dirty_files: list<string>
  machine_files: record
] {
  log info "Checking affected machines using cached graphs..."
  mut results = {}

  for dirty_file in $dirty_files {
    log info $"  Checking: ($dirty_file)"
    let affected_machines = $machine_files
    | items { |machine, files|
        if ($dirty_file in $files) {
          $machine
        }
      }
    | where ($it != null)
    | sort

    if not ($affected_machines | is-empty) {
      $results = ($results | insert $dirty_file $affected_machines)
      log info $"    Affects: ($affected_machines | str join ', ')"
    } else {
      log info "    Affects: none"
    }
  }

  $results
}

def output_results [
  results: record
  dirty_files: list<string>
  json_mode: bool
] {
  if $json_mode {
    # Create machine -> files mapping for JSON output
    mut machine_to_files = {}

    for dirty_file in $dirty_files {
      let affected_machines = $results | get -o $dirty_file | default []
      for machine in $affected_machines {
        let current_files = $machine_to_files | get -o $machine | default []
        $machine_to_files = ($machine_to_files | insert $machine ($current_files | append $dirty_file | uniq))
      }
    }

    print ($machine_to_files | to json)

    return
  }

  if ($results | is-empty) {
    log info "No machines affected by current dirty files."
    return
  }

  log info ""
  log info "Summary - Affected files and their machines:"

  for dirty_file in $dirty_files {
    let machines = $results | get -o $dirty_file | default []
    if not ($machines | is-empty) {
      log info $"- ($dirty_file):"
      $machines | each { |machine| log info $"  - ($machine)" }
    }
  }
}
