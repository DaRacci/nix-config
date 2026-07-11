#!/usr/bin/env -S nix shell nixpkgs#nushell --command nu

use std/log
use lib/flake.nu
use lib/lib.nu

def main [
  --since: string # Git commit/ref used to filter results to files changed since that point
  --refine # Try narrow affected hosts/homes by checking detected enable options
  --report # Print summary table of recommended actions
] {

  log info "Getting flake information..."
  let flake_info = get_flake_info

  let changed_files = if $since != null {
    log info $"Getting changed files since: ($since)"
    get_changed_files_since $since
  } else {
    []
  }

  log info "Getting host configurations..."
  let hosts = get_hosts $flake_info.hosts $flake_info.source

  log info "Getting home configurations..."
  let homes = get_homes $flake_info.homes $flake_info.source

  log info "Building module graph..."
  let all_modules = build_module_graph $hosts $homes

  let filtered_modules = if $since != null {
    log info "Filtering module graph to affected files..."
    $all_modules | where { |entry| $entry.file in $changed_files }
  } else {
    $all_modules
  }

  log info $"Total modules: ($all_modules | length), Affected modules: ($filtered_modules | length)"

  let refined_modules = if $refine {
    log info "Refining module graph with detected enable options..."
    refine_module_graph $filtered_modules
  } else {
    $filtered_modules
  }

  log info $"Total modules with refinement: ($refined_modules | length)"

  if $report {
    log info "Generating summary report..."
    generate_report $refined_modules $changed_files
  } else {
    $refined_modules | to json
  }
}

def get_flake_info [] {
  let hosts = try {
    log debug "Evaluating nixosConfigurations (attr names)"
    nix eval --json .#nixosConfigurations --apply 'builtins.attrNames' | from json
  } catch { |err|
    log warning $"Failed to get nixosConfigurations primary method: ($err)"
    []
  }

  let homes = try {
    log debug "Evaluating homeConfigurations (attr names)"
    nix eval --json .#homeConfigurations --apply 'builtins.attrNames' | from json
  } catch { |err|
    log warning $"Failed to get homeConfigurations primary method: ($err)"
    []
  }

  if ($hosts | is-empty) {
    log warning "Host list came back empty"
  }
  if ($homes | is-empty) {
    log warning "Home list came back empty"
  }

  let flake_source = (flake get_flake_info).source_path
  let flake_info = { hosts: $hosts, homes: $homes, source: $flake_source }
  $flake_info
}

def get_changed_files_since [since: string] {
  let tracked_changes = try {
    git diff --name-only $since | lines
  } catch { |err|
    log error $"Failed to get changed files since '($since)': ($err)"
    exit 1
  }

  let untracked_changes = try {
    git ls-files --others --exclude-standard | lines
  } catch { |err|
    log error $"Failed to get untracked files: ($err)"
    exit 1
  }

  let changed_files = ($tracked_changes ++ $untracked_changes)
    | where { |file| $file != "" }
    | uniq

  if ($changed_files | is-empty) {
    log warning $"No changed files found since '($since)'"
  }

  $changed_files
}

def get_hosts [
  host_names: list<string>
  flake_source: string
] {
  let host_configs = $host_names | reduce -f {} { |host, acc|
    log debug $"Getting imports for host: ($host)"
    try {
      let imports = flake get_output_graph_files $"nixosConfigurations.($host)" $flake_source
      $acc | insert $host $imports
    } catch { |err|
      log warning $"Failed to get imports for host: ($host) - ($err)"
      $acc | insert $host []
    }
  }

  $host_configs
}

def get_homes [
  home_names: list<string>
  flake_source: string
] {
  let home_configs = $home_names | reduce -f {} { |home, acc|
    log debug $"Getting imports for home: ($home)"
    try {
      let imports = flake get_output_graph_files $"homeConfigurations.($home)" $flake_source
      $acc | insert $home $imports
    } catch { |err|
      log warning $"Failed to get imports for home: ($home) - ($err)"
      $acc | insert $home []
    }
  }

  $home_configs
}

def build_module_graph [hosts: record, homes: record] {
  let all_host_modules = $hosts | values | flatten | uniq
  let all_home_modules = $homes | values | flatten | uniq
  let all_modules = ($all_host_modules ++ $all_home_modules) | uniq

  $all_modules | each { |module_file|
    let hosts_using_module = $hosts | items { |key, value|
      if ($module_file in $value) {
        $key
      }
    } | where { $in != null }

    let homes_using_module = $homes | items { |key, value|
      if ($module_file in $value) {
        $key
      }
    } | where { $in != null }

    {
      file: $module_file
      hosts: $hosts_using_module
      homes: $homes_using_module
    }
  }
}

def refine_module_graph [module_graph: list] {
  $module_graph | each { |entry|
    refine_module_graph_entry $entry
  }
}

def refine_module_graph_entry [entry: record] {
  if not (supports_enable_option_refinement $entry.file) {
    $entry | insert refinement {
      mode: "none"
      reason: "unsupported-file-path"
    }
  } else {
    let enable_options = detect_enable_options $entry.file

    if ($enable_options | is-empty) {

      $entry | insert refinement {
        mode: "none"
        reason: "no-enable-option-detected"
      }
    } else if ($enable_options | length) > 1 {
      log debug $"Skipping refinement for '($entry.file)': multiple enable options detected"
      $entry | insert refinement {
        mode: "none"
        reason: "multiple-enable-options-detected"
        options: $enable_options
      }
    } else {
      let option_path = ($enable_options | first)
      let refined_hosts = refine_targets_by_option "nixosConfigurations" $entry.hosts $option_path
      let refined_homes = refine_targets_by_option "homeConfigurations" $entry.homes $option_path

      let final_hosts = if ($entry.hosts | is-empty) or not ($refined_hosts | is-empty) {
        $refined_hosts
      } else {
        $entry.hosts
      }
      let final_homes = if ($entry.homes | is-empty) or not ($refined_homes | is-empty) {
        $refined_homes
      } else {
        $entry.homes
      }

      $entry
      | upsert hosts $final_hosts
      | upsert homes $final_homes
      | insert refinement {
        mode: "enable-option"
        option: $option_path
        hosts_before: $entry.hosts
        hosts_after: $final_hosts
        homes_before: $entry.homes
        homes_after: $final_homes
        hosts_refined: ($final_hosts != $entry.hosts)
        homes_refined: ($final_homes != $entry.homes)
      }
    }
  }
}

def supports_enable_option_refinement [file_path: string] {
  ($file_path | str starts-with "modules/nixos/") or ($file_path | str starts-with "modules/home-manager/")
}

def detect_enable_options [file_path: string] {
  # only run detection for files under modules/nixos or modules/home-manager
  # (extra guard; callers already check this, but keep here safe)
  if not (supports_enable_option_refinement $file_path) {
    return []
  }

  let file_contents = try {
    open $file_path
  } catch { |err|
    log warning $"Failed to read '($file_path)' for refinement: ($err)"
    return []
  }

  let nested_options = ($file_contents
    | parse --regex '(?ms)options\.(?<path>[A-Za-z0-9_.-]+)\s*=\s*\{.*?enable\s*=\s*(?:lib\.)?(?:mkEnableOption|mkOption)'
    | get -o path
    | default [])

  let direct_options = ($file_contents
    | parse --regex '(?m)options\.(?<path>[A-Za-z0-9_.-]+)\.enable\s*=\s*(?:lib\.)?(?:mkEnableOption|mkOption)'
    | get -o path
    | default [])

  ($nested_options ++ $direct_options)
  | uniq
  | sort
}

def refine_targets_by_option [
  output_kind: string
  targets: list<string>
  option_path: string
] {
  $targets | where { |target|
    is_option_enabled_for_target $output_kind $target $option_path
  }
}

def is_option_enabled_for_target [
  output_kind: string
  target: string
  option_path: string
] {
  let attr_path = lib quote_nix_segments $".#($output_kind).($target).config.($option_path).enable"

  try {
    let result = (nix eval --json $attr_path | from json)
    $result == true
  } catch {
    true
  }
}

# Report generation
# - aggregate counts per host/home
# - group hosts/homes into priority buckets
def generate_report [module_graph: list, changed_files: list] {
  mut host_counts = {}
  mut home_counts = {}

  for entry in $module_graph {
    for h in $entry.hosts { $host_counts = ($host_counts | upsert $h (($host_counts | get -o $h | default 0) + 1)) }
    for m in $entry.homes { $home_counts = ($home_counts | upsert $m (($home_counts | get -o $m | default 0) + 1)) }
  }

  let host_rows = $host_counts | items {|key, value| { name: $key, count: $value } } | sort-by { $in.count } -r
  let home_rows = $home_counts | items {|key, value| { name: $key, count: $value } } | sort-by { $in.count } -r

  let host_table = [
    { priority: "HIGH", rows: ($host_rows | where { $in.count > 3 }) },
    { priority: "MEDIUM", rows: ($host_rows | where { ($in.count > 1) and ($in.count <= 3) }) },
    { priority: "LOW", rows: ($host_rows | where { $in.count == 1 }) }
  ]

  let home_table = [
    { priority: "HIGH", rows: ($home_rows | where { $in.count > 3 }) },
    { priority: "MEDIUM", rows: ($home_rows | where { ($in.count > 1) and ($in.count <= 3) }) },
    { priority: "LOW", rows: ($home_rows | where { $in.count == 1 }) }
  ]

  print_section "NixOS HOSTS" $host_table
  print_section "HOME-MANAGER CONFIGS" $home_table
}

def print_section [title: string, table: list] {
  print ""
  print "*************************************************************"
  print $"  ($title)"
  print "*************************************************************"
  print ""

  for section in $table {
    if ($section.rows | length) > 0 {
      print $"Priority: ($section.priority)"
      for r in $section.rows {
        print $"  - ($r.name) [($r.count) modules]"
      }
      print ""
    }
  }
}
