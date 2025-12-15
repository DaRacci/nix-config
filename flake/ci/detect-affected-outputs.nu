#!/usr/bin/env -S nix shell nixpkgs#nushell --command nu

use std/log
use ../dev/scripts/lib/flake.nu

# Detect which outputs are affected based on changed files in the git repo.
def main [
  type: string # Type of output to check (e.g., "nixosConfigurations" or "homeConfigurations")
  --verbose (-v)  # Enable verbose logging
  --range: string # Git range to check
  --json (-j) # Output JSON format
  ...files: string # Specific files to check
] {
  init_logging $verbose $json

  let flake_info = get_flake_info
  let cache_dir = $"($env.GIT_ROOT)/.cache/($type)-graphs"
  let cache_key = init_cache $flake_info $cache_dir
  let dirty_files = collect_files $files $range

  let outputs = get_outputs $type
  if ($outputs | is-empty) {
    log error $"No outputs found for identifier ($type) in flake."
    exit 1
  }
  log info $"Found outputs: ($outputs | str join ', ')"

  let output_imports: record = compute_graphs $type $outputs $cache_key $cache_dir $flake_info.source_path
  let results = check_affected_outputs $dirty_files $output_imports

  output_results $results $dirty_files $json
}

def --env init_logging [
  verbose: bool
  json: bool
] {
  log set-level (if $json { 61 } else if $verbose { 10 } else { 20 })
  $env.NU_LOG_FORMAT = "%ANSI_START%%LEVEL%|%MSG%%ANSI_STOP%"
}

def init_cache [
  flake_info: record
  cache_dir: string
] {
  let cache_key = $flake_info.hash
  mkdir $cache_dir

  let cache_files = ls $cache_dir | get name
  let pattern = $"\(.*)-($cache_key)$"
  let not_matching = $cache_files | where { |name| $name !~ $pattern }

  if not ($not_matching | is-empty) {
    log info "Cleaning up old cache files..."
    $not_matching | each { |old_file| log info $"  Removing old cache file: ($old_file)" }
    $not_matching | each { |old_file| rm $old_file }
  }

  return $cache_key
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

def collect_files [
  files: list<string>
  range?: string
] {
  mut dirty_files = $files
  if not ($range | is-empty) {
    $dirty_files = $dirty_files | append (get_dirty_files_from_git_range $range)
  }

  if ($dirty_files | is-empty) {
    $dirty_files = get_dirty_files_from_git
  }

  if ($dirty_files | is-empty) {
    log info "No dirty files to process."
    exit 0
  }

  log info $"Dirty files to process -- total: ($dirty_files | length):"
  $dirty_files | each { |f| log info $"  ($f)" }

  $dirty_files | sort | uniq
}

def get_outputs [
  identifier: string
] {
  try {
    nix eval --json $".#($identifier)" --apply 'builtins.attrNames' | from json
  } catch { |err|
    log error $"Failed to get graphs: ($err)"
    exit 1
  }
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

def compute_graphs [
  type: string
  outputs: list<string>
  cache_key: string
  cache_dir: string
  flake_source: string
] {
  log info "Computing and caching file graphs for all outputs..."

  mut output_files = {}
  for output in $outputs {
    let cache_file = $"($cache_dir)/($output)-($cache_key)"

    if ($cache_file | path exists) {
      log info $"  Loading cached graph for ($output)..."
      let cached_content = open $cache_file | from json
      $output_files = ($output_files | insert $output $cached_content)
      log info $"    Loaded ($cached_content | length) files from cache"
      continue
    }

    log info $"  Computing graph for ($output)..."
    let files: list<string> = collect_files_from_graph $type $output $".#($type).($output).graph" $flake_source
    $files | to json | save $cache_file
    $output_files = ($output_files | insert $output $files)
    log info $"    Computed and cached ($files | length) files"
  }

  $output_files
}

def collect_files_from_graph [
  type: string
  identifier: string
  eval_str: string
  flake_source: string
] {
  let raw_files = try {
    # Write graph to temp file to avoid nix eval piping issues in nushell
    let graph_file = $"/tmp/graph-($identifier).json"
    try {
      run-external "nix" "eval" "--json" $eval_str o> $graph_file
    } catch { |err|
      log error $"Failed to evaluate graph for ($identifier): ($err)"
      exit 1
    }

    mut files = open $graph_file
      | flatten_graph_recursively
      | where ($it | get -o file | default "" | str starts-with $"($flake_source)/")
      | get file
      | each { |file| $file | str replace $"($flake_source)/" "" }

    $files = $files | append (match $type {
      "nixosConfigurations" => [
        "flake.lock"
        "flake/nixos/flake.lock"
      ]
      "homeConfigurations" => [
        "flake.lock"
        "flake/home-manager/flake.lock"
      ]
      _ => {
        log warning $"Unknown type ($type) for additional file handling."
        []
      }
    })

    rm $graph_file
    $files | sort | uniq
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

def check_affected_outputs [
  dirty_files: list<string>
  output_files: record
] {
  log info "Checking affected outputs using cached graphs..."
  mut results = {}

  for dirty_file in $dirty_files {
    log info $"  Checking: ($dirty_file)"
    let affected_outputs = $output_files
    | items { |output, files|
        if ($dirty_file in $files) {
          $output
        }
      }
    | where ($it != null)
    | sort

    if not ($affected_outputs | is-empty) {
      $results = ($results | insert $dirty_file $affected_outputs)
      log info $"    Affects: ($affected_outputs | str join ', ')"
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
    mut output_to_files = {}

    for dirty_file in $dirty_files {
      let affected_outputs = $results | get -o $dirty_file | default []
      for output in $affected_outputs {
        let current_files = $output_to_files | get -o $output | default []
        $output_to_files = ($output_to_files | upsert $output ($current_files | append $dirty_file | uniq))
      }
    }

    print ($output_to_files | to json)

    return
  }

  if ($results | is-empty) {
    log info "No outputs affected by current dirty files."
    return
  }

  log info ""
  log info "Summary - Affected files and their outputs:"

  for dirty_file in $dirty_files {
    let output = $results | get -o $dirty_file | default []
    if not ($output | is-empty) {
      log info $"- ($dirty_file):"
      $output | each { |output| log info $"  - ($output)" }
    }
  }
}
