#!/usr/bin/env nu

use std/log
use lib/flake.nu *

const ACTIONS = ["switch" "build" "boot" "test" "build-vm"]

def "nu-complete rebuild-target first-arg" [] {
  # First arg can be action or hostname, suggest both
  let actions = $ACTIONS
  let hosts = try { list_hosts --fast } catch { [] }
  ($actions ++ $hosts | sort | uniq)
}

def "nu-complete rebuild-target second-arg" [context: string] {
  # Context: "rebuild-target arg1 arg2 ..."
  # Find first arg by skipping script name
  let words = ($context | split words)

  # Filter out script name components (rebuild, target, and .nu files)
  let first_arg = (
    $words
    | where { |w|
        ($w != "rebuild") and ($w != "target") and (not ($w | str ends-with ".nu"))
    }
    | get -o 0
    | default ""
  )

  if ($first_arg in $ACTIONS) {
    try { list_hosts --fast } catch { [] }
  } else {
    $ACTIONS
  }
}

def perform-action [
  action: string # "switch" | "build" | "boot" | "test" | "build-vm"
  hostname?: string
  ...rest_args: string
] {
  let selected = if ($hostname != null) {
    $hostname
  } else {
    select_host --fast
  }

  if $selected == null {
    log error "No host selected."
    exit 1
  }

  let command_args = [
    "os"
    $action
    $".#nixosConfigurations.($selected)"
  ]

  let passthrough_args = [
    "--"
    "--accept-flake-config"
    ...($rest_args)
  ]

  log info $"Selected host: ($selected)"
  log info $"Command: ($command_args) with passthrough ($passthrough_args)"

  if $action != "build-vm" {
    if $selected == $env.CURRENT_HOST {
      log info $"Performing ($action) on current host"
      nh ...$command_args ...($passthrough_args)
    } else {
      log info $"Performing ($action) on selected host: ($selected)"
      nh ...$command_args --target-host $"root@($selected)" ...($passthrough_args)
    }
  } else {
    log info $"Building VM for selected host: ($selected)"
    nh ...$command_args --diff never --hostname $selected ...($passthrough_args)
    if $env.LAST_EXIT_CODE != 0 {
      return
    }

    let run_path = $"./result/bin/run-($selected)-vm"
    exec $run_path -nographic
  }
}

def perform-rebuild-action [
  arg1?: string
  arg2?: string
  ...rest_args: string
] {
  let args = ([(if $arg1 != null { [$arg1] } else { [] }), (if $arg2 != null { [$arg2] } else { [] })] | flatten)
  let all_args = $args ++ $rest_args
  let parsed = parse-flexible-args $all_args --valid-actions $ACTIONS --default-action "switch"
  perform-action $parsed.action $parsed.hostname ...$parsed.rest
}

export def rebuild-target [
  arg1?: string@"nu-complete rebuild-target first-arg"     # first arg: action or hostname
  arg2?: string@"nu-complete rebuild-target second-arg"     # second arg: depends on first
  ...rest_args: string
] {
  perform-rebuild-action $arg1 $arg2 ...$rest_args
}

def --wrapped main [
  arg1?: string
  arg2?: string
  ...rest_args: string
] {
  perform-rebuild-action $arg1 $arg2 ...$rest_args
}
