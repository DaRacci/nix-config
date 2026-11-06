#!/usr/bin/env nu

use std/log
use lib/common.nu *

def current_system [] {
  nix eval --raw --impure --expr "builtins.currentSystem"
}

def available_tests [system: string] {
  nix eval --json $".#tests.($system)" --apply "builtins.attrNames" | from json
}

def main [
  ...names: string, # Tests to run
  --all(-a), # Run every test for the selected system
  --list(-l), # List available tests instead of running them
  --system(-s): string = "", # Nix system to evaluate; defaults to the current system
] {
  cd $env.GIT_ROOT

  let system = if $system == "" { current_system } else { $system }
  let available = available_tests $system

  if $list {
    print ($available | each { |name| $"($system).($name)" } | str join "\n")
    cd -
    return
  }

  if (($names | is-empty) and (not $all)) {
    cd -
    fail "no tests selected; pass one or more names or --all (use --list to see available tests)"
  }

  let selected = if $all { $available } else { $names }
  let unknown = $selected | where { |name| not ($name in $available) }

  if not ($unknown | is-empty) {
    cd -
    fail $"unknown tests: ($unknown | str join ', ')"
  }

  for name in $selected {
    log info $"Running test: ($name)"
    nix build --no-link --print-build-logs $".#tests.($system).($name)"
  }

  cd -
}
