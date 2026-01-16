#!/usr/bin/env nu

use std/log
use lib/lib.nu *
use lib/flake.nu *

def get_packages [
  arch: string # The architecture to get packages for
] {
  let packages = nix flake show --no-pure-eval --json e> /dev/null | jq $'.packages."($arch)" | keys' | from json
  return $packages
}

def filter_packages [
  arch: string
  ...package_names: string
] {
  mut valid_packages = []

  for package in $package_names {
    let pkg_details = nix eval --json --system $arch $'.#($package)' --apply 'pkg: { discovery = pkg.passthru.discovery or true; inherit (pkg.meta) broken; }' | from json
    log info $"Package ($package)\n\tisBroken: ($pkg_details.broken)\n\tisDiscoverable: ($pkg_details.discovery)"

    if ($pkg_details.discovery and (not $pkg_details.broken)) {
      $valid_packages = $valid_packages | append $package
    }
  }

  return $valid_packages
}

export def get_package_location [
  package_name: string
] {
  let eval_nix = "/persist/nix-config/flake/ci/scripts/eval.nix"
  let attribute_json = ["packages", "x86_64-linux", $package_name] | to json
  let cmd = [
    "--eval",
    "--json",
    "--strict",
    $eval_nix,
    "--argstr",
    "importPath",
    "/persist/nix-config"
    "--argstr",
    "attribute",
    $attribute_json
  ]

  mut package_path = ""
  try {
    $package_path = (nix-instantiate ...$cmd) | from json | path dirname
  } catch {
    log warning $"Unable to evaluate location from nix positions for ($package_name)"
  }
  if ($package_path | is-empty) {
    $package_path = $"pkgs/($package_name)"
  }

  return $package_path
}

def get_changed [
  git_range: string
  ...packages: string
] {
  let nixpkgs_changed = has_flake_inputs_changed $git_range "nixpkgs"
  if $nixpkgs_changed {
    return $packages
  }

  mut changed_packages = [ ];
  for package in $packages {
    let pkg_folder = get_package_location $package
    if (not ($pkg_folder | path exists)) {
      log warning $"Package folder ($pkg_folder) does not exist, maybe it isn't a normal package and should be excluded from discovery."
      continue
    }

    let all_related_files = ls $pkg_folder | get name
    log info $"Checking package ($package) for changes, files: ($all_related_files)"

    let changed = check_file_changed $git_range ...$all_related_files
    if $changed {
      log info $"Package ($package) has changed."
      $changed_packages = $changed_packages | append $package
    }
  }

  return $changed_packages
}

def main [
  git_range: string
  --arch: string            # The architecture to get packages for
  --json (-j)               # Output in JSON format
  ...package_names: string  # Only look for changes to these packages
] {
  let arch = if ($arch | is-empty) { nix eval --raw --impure --expr builtins.currentSystem } else { $arch }
  mut packages = $package_names
  if ($packages | is-empty) {
    $packages = get_packages $arch
  }
  let valid_packages = filter_packages $arch ...$packages
  let changed_packages = get_changed $git_range ...$valid_packages

  if ($json) {
    return ($changed_packages | to json)
  } else {
    return $changed_packages
  }
}
