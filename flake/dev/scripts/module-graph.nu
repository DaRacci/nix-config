#!/usr/bin/env -S nix shell nixpkgs#nushell --command nu

use std/log
use lib/flake.nu

def main [
  --since: string # Git commit/ref used to filter results to files changed since that point
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
    filter_module_graph_by_changed_files $all_modules $changed_files
  } else {
    $all_modules
  }

  $filtered_modules | to json
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

  if ($hosts | is-empty) { log warning "Host list came back empty" }
  if ($homes | is-empty) { log warning "Home list came back empty" }

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
    log warning $"Failed to get untracked files: ($err)"
    []
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
  host_names: list<string>,
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
  home_names: list<string>,
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
      file: $module_file,
      hosts: $hosts_using_module,
      homes: $homes_using_module
    }
  }
}

def filter_module_graph_by_changed_files [
  module_graph: list,
  changed_files: list<string>
] {
  if ($changed_files | is-empty) {
    []
  } else {
    $module_graph | where { |entry| $entry.file in $changed_files }
  }
}
