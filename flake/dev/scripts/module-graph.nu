#!/usr/bin/env -S nix shell nixpkgs#nushell --command nu

use std/log

def main [] {
  log info "Getting flake information..."
  let flake_info = get_flake_info

  log info "Getting host configurations..."
  let hosts = if ($flake_info.hosts != null) { get_hosts $flake_info.hosts } else { get_hosts [] }

  log info "Getting home configurations..."
  let homes = if ($flake_info.homes != null) { get_homes $flake_info.homes } else { get_homes [] }

  log info "Building module graph..."
  let all_modules = build_module_graph $hosts $homes

  $all_modules | to json
}

def get_flake_info [] {
  let current_dir = $env.PWD

  let hosts = try {
    log debug "Evaluating nixosConfigurations (attr names)"
    nix eval --json .#nixosConfigurations --apply 'builtins.attrNames' --override-input devenv-root $"file+file://($current_dir)/.devenv/root" | from json
  } catch { |err|
    log warning $"Failed to get nixosConfigurations primary method: ($err)"
    []
  }

  let homes = try {
    log debug "Evaluating homeConfigurations (attr names)"
    nix eval --json .#homeConfigurations --apply 'builtins.attrNames' --override-input devenv-root $"file+file://($current_dir)/.devenv/root" | from json
  } catch { |err|
    log warning $"Failed to get homeConfigurations primary method: ($err)"
    []
  }

  if ($hosts | is-empty) { log warning "Host list came back empty" }
  if ($homes | is-empty) { log warning "Home list came back empty" }
  let flake_info = { hosts: $hosts, homes: $homes }
  $flake_info
}

def get_hosts [host_names: list<string>] {
  let current_dir = $env.PWD
  let this_source = nix flake archive --json | from json | get path

  let host_configs = $host_names | reduce -f {} { |host, acc|
    log debug $"Getting imports for host: ($host)"
    try {
      let raw_imports = nix eval --json $".#nixosConfigurations.($host)" --apply $"(cat ./utils/get-os-imports.nix)" --show-trace --override-input devenv-root $"file+file://($current_dir)/.devenv/root" | from json
      let our_imports = $raw_imports
        | where { $in | str starts-with $this_source }
        | each { |import|
            if not ($import | str ends-with ".nix") {
              $"($import)/default.nix"
            } else {
              $import
            }
          }
        | each { |import| $import | str substring (($this_source | str length) + 1).. }
        | uniq

      $acc | insert $host $our_imports
    } catch { |err|
      log warning $"Failed to get imports for host: ($host) - ($err)"
      $acc | insert $host []
    }
  }

  $host_configs
}

def get_homes [home_names: list<string>] {
  let current_dir = $env.PWD
  let this_source = nix flake archive --json | from json | get path

  let home_configs = $home_names | reduce -f {} { |home, acc|
    log debug $"Getting imports for home: ($home)"
    try {
      let raw_imports = nix eval --json $".#homeConfigurations.($home)" --apply $"(cat ./utils/get-hm-imports.nix)" --show-trace --override-input devenv-root $"file+file://($current_dir)/.devenv/root" | from json
      let our_imports = $raw_imports
        | where { $in | str starts-with $this_source }
        | each { |import|
            if not ($import | str ends-with ".nix") {
              $"($import)/default.nix"
            } else {
              $import
            }
          }
        | each { |import| $import | str substring (($this_source | str length) + 1).. }
        | uniq

      $acc | insert $home $our_imports
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
