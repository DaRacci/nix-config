use std/log

export-env {
  $env.GIT_ROOT = ($env.PWD | git rev-parse --show-toplevel | str trim)
  $env.CURRENT_HOST = (cat /etc/hostname | str trim)
  $env.CURRENT_USER = (whoami | str trim)
}

# Get a list of all hosts.
# Use the --fast switch to estimate the hosts based on fs instead of nix for quicker scans.
export def list_hosts [--fast] {
  mut hosts = []

  if $fast {
    let hosts_dir = ($env.GIT_ROOT | path join "hosts")
    let host_types = ^find $hosts_dir -mindepth 1 -maxdepth 1 -type d -print | lines;
    for $host_type in $host_types {
      let host_type_dir = ($hosts_dir | path join $host_type)
      let raw_dirs = ^find $host_type_dir -mindepth 1 -maxdepth  1 -type d -print | lines | each { $in | path basename };
      let host_names = $raw_dirs | where { $in != $env.CURRENT_HOST and $in != "shared" } | sort | uniq
      $hosts = $hosts ++ $host_names
    }
  } else {
    $hosts = flake-eval r#'builtins.attrNames flake.nixosConfigurations |> builtins.concatStringsSep " "'#  --raw
      | split words
      | where $it != $env.CURRENT_HOST
  }

  $hosts
}

export def select_host [--fast] {
  let hosts = list_hosts --fast=$fast
  let all_hosts = ["current", ...($hosts)]
  let selected = $all_hosts | input list -f
  if $selected == "current" {
    $env.CURRENT_HOST
  } else {
    $selected
  }
}

# Parse flexible args where action and hostname can be in different orders
# Returns {action: string, hostname: string|null, rest: list<string>}
# Examples with actions=["build" "switch"] and default_action="switch":
#   parse-flexible-args [] => {action: "switch", hostname: null, rest: []}
#   parse-flexible-args ["host1"] => {action: "switch", hostname: "host1", rest: []}
#   parse-flexible-args ["build" "host1"] => {action: "build", hostname: "host1", rest: []}
#   parse-flexible-args ["host1" "--flag"] => {action: "switch", hostname: "host1", rest: ["--flag"]}
export def parse-flexible-args [
  args: list<string>
  --valid-actions: list<string> = []
  --default-action: string = "switch"
] {
  if ($args | is-empty) {
    return {action: $default_action, hostname: null, rest: []}
  }

  let first = ($args | get 0)

  if ($first in $valid_actions) {
    let hostname = if ($args | length) > 1 { $args | get 1 } else { null }
    let rest = if ($args | length) > 2 { $args | range 2.. } else { [] }
    return {action: $first, hostname: $hostname, rest: $rest}
  }

  let rest = if ($args | length) > 1 { $args | range 1.. } else { [] }
  return {action: $default_action, hostname: $first, rest: $rest}
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
