#!/usr/bin/env nu

use std/log
use lib/common.nu

# Mark matrix entries that should build for the current pipeline.
#
# With `--json`, writes the affected list to a file for build workflows to
# read. Otherwise writes `.do-build-<output>` markers into the shared workspace.
def main [
  kind: string # hosts, homes, or packages
  --json: string # Write affected outputs as JSON to this path instead of markers
] {
  if $kind not-in [ "hosts" "homes" "packages" ] {
    log error $"Unknown kind ($kind); expected hosts, homes, or packages"
    exit 1
  }

  let markers = (glob ".do-build-*")
  if not ($markers | is-empty) {
    rm --force ...$markers
  }

  let event = ($env.CI_PIPELINE_EVENT? | default "manual")
  let prev_status = ($env.CI_PREV_PIPELINE_STATUS? | default "")

  mut build_all = ($prev_status == "failure")
  mut range = ""

  if $event == "pull_request" {
    let target = ($env.CI_COMMIT_TARGET_BRANCH? | default "")
    if ($target | is-empty) {
      $build_all = true
    } else {
      let fetched = (do -i { git fetch origin $target --no-tags } | complete)
      if $fetched.exit_code != 0 {
        log warning $"Failed to fetch target branch ($target); building all"
        $build_all = true
      } else {
        $range = $"origin/($target)..HEAD"
      }
    }
  } else {
    let prev = ($env.CI_PREV_COMMIT_SHA? | default "")
    if ($prev | is-empty) {
      $build_all = true
    } else {
      let exists = (do -i { git cat-file -e $"($prev)^{commit}" } | complete)
      if $exists.exit_code != 0 {
        log warning $"Previous commit ($prev) unavailable; building all"
        $build_all = true
      } else {
        $range = $"($prev)..HEAD"
      }
    }
  }

  let affected = if $build_all {
    log info "Building all outputs"
    get_all $kind
  } else {
    log info $"Detecting affected outputs for ($range)"
    try {
      match $kind {
        "hosts" => (nix run .#detect-affected-outputs -- nixosConfigurations --json --range $range | from json | columns)
        "homes" => (nix run .#detect-affected-outputs -- homeConfigurations --json --range $range | from json | columns)
        "packages" => (nix run .#discover-packages -- --json $range | from json)
        _ => [ ]
      }
    } catch { |err|
      log warning $"Affected-output detection failed: ($err.msg); building all"
      get_all $kind
    }
  }

  if ($affected | is-empty) {
    log info "No affected outputs"
  } else if not ($json | is-empty) {
    $affected | to json | save --force $json
    log info $"Wrote affected outputs to ($json)"
    return
  } else {
    for output in $affected {
      touch $".do-build-($output)"
      log info $"Affected: ($output)"
    }
  }

  if not ($json | is-empty) {
    [ ] | to json | save --force $json
    log info $"Wrote empty affected outputs to ($json)"
  }
}

def get_all [kind: string] {
  let attr = match $kind {
    "hosts" => "nixosConfigurations"
    "homes" => "homeConfigurations"
    "packages" => "packages.x86_64-linux"
    _ => ""
  }

  nix eval --json $".#($attr)" --apply builtins.attrNames | from json
}
