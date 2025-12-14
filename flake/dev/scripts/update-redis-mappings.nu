#!/usr/bin/env nu

use std/log
use lib/flake.nu *

let FILE_LOCATION = $"($env.GIT_ROOT)/hosts/server/nixio/redis-mappings.json"
const MAX_DATABASES = 16

# Assign a numeric id to each service into range [0..max-1].
# Uses sha256sum to pick an initial candidate, then linear-probes for a free slot.
# Writes the mappings to a JSON file that is consumed by the redis database module.
def main [
  --verbose
] {
  log set-level (if $verbose { 10 } else { 20 })
  $env.NU_LOG_FORMAT = "%ANSI_START%%LEVEL%|%MSG%%ANSI_STOP%"

  mut existing: record<service: string, id: int> = {}
  mut used: list<int> = []
  if ($FILE_LOCATION | path exists) {
    $existing = open $FILE_LOCATION
    $used = $existing | values | each { $in | into int }

    log debug $"Loaded existing mappings: {($existing | to json)}"
  }

  let services: list<string> = get_services
  log debug $"Discovered services: {($services | to json)}"
  let new = $services | where {|s| not ($existing | columns | any {|e| $s == $e }) }
  log debug $"New services needing assignment: {($new | to json)}"

  if ($new | length) == 0 {
    log info "No new services to assign"
    log info $"Existing mappings: {($existing | to json)}"
    exit 0
  }
  log info $"Assigning ids for new services: {($new | to json)}"

  mut available = 0..($MAX_DATABASES - 1) | where {|id| not ($used | any {|u| $id == $u }) }
  if ($available | length) < ($new | length) {
    log error "Not enough available slots to assign new services"
    log error $"Available slots: {($available | to json)}"
    log error $"New services: {($new | to json)}"
    exit 1
  }

  mut new_mappings: record<service: string, id: int> = {}
  for service in $new {
    let id = assign-id $service $available
    if $id == null {
      log error $"Failed to assign id for service ($service)"
      exit 1
    }

    log info $"Assigned ($service) -> ($id)"
    $new_mappings = $new_mappings | merge  { $service: $id }
    $used = $used | append $id
    $available = $available | where {|a| $a != $id }
  }
  log debug $"New mappings: {($new_mappings | to json)}"

  let updated = ($existing | merge $new_mappings | sort)
  log info $"Updated mappings: {($updated | to json)}"
  $updated | to json | save --force $FILE_LOCATION
}

def get_services [] {
  flake-eval r#'
    let
      inherit (flake.inputs.nixpkgs) lib;
      serverConfigurations = lib.trivial.pipe flake.nixosConfigurations [
        builtins.attrValues
        (builtins.map (host: host.config))
        (builtins.filter (cfg: cfg.host.device.role == "server"))
        (builtins.filter (cfg: cfg.server.database ? postgres && cfg.server.database.postgres != { }))
      ];

      gatherAllInstances =
        attrPath:
        lib.pipe serverConfigurations [
          (builtins.filter (cfg: cfg.host.name != "nixio"))
          (builtins.map (cfg: lib.attrsets.attrByPath (lib.splitString "." attrPath) null cfg))
          (builtins.filter (
            item:
            if lib.isList item then
              item != [ ]
            else if lib.isAttrs item then
              item != { }
            else
              item != null
          ))
        ];
    in gatherAllInstances "server.database.redis" |> lib.mergeAttrsList |> builtins.attrNames |> lib.flatten
  '# --json | from json
}

def assign-id [
  service: string,
  available: list<int>,
] {
  let slot = 0
  mut found = false
  while $found == false {
    if ($available | where { $in == $slot } | length) > 0 {
      $found = true
    } else {
      let slot = ($slot + 1) mod $MAX_DATABASES
      if $slot == 0 {
        # wrapped around, no slots available
        return null
      }
    }
  }

  return $slot
}
