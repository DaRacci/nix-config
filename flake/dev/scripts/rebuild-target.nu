#!/usr/bin/env nu

use std/log
use lib/flake.nu *

def perform-action [
  action: string # "switch" | "build" | "boot" | "test" | "build-vm"
  args: list<string>
] {
  let selected = select_host

  let command_args = [
    "os"
    $action
    $".#nixosConfigurations.($selected)"
  ]

  let passthrough_args = [
    "--"
    "--accept-flake-config"
    ...($args)
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
    nh ...$command_args ...($passthrough_args)
  }
}

def --wrapped main [...args: string] {
  perform-action "switch" $args
}

def --wrapped "main build-vm" [...args: string] {
  perform-action "build-vm" $args
}

def --wrapped "main test" [...args: string] {
  perform-action "test" $args
}

def --wrapped "main build" [...args: string] {
  perform-action "build" $args
}

def --wrapped "main boot" [...args: string] {
  perform-action "boot" $args
}
