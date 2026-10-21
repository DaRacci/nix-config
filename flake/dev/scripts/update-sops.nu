#!/usr/bin/env nu

use std/log
use lib/flake.nu *

const SOPS_FILE = ".sops.yaml"
const AGE_KEYS_FILE = "sops-keys.nix"
const HOST_KEY_FILE = "ssh_host_ed25519_key.pub"
const HOME_KEY_FILE = "id_ed25519.pub"
const DEPLOYER_AGE_KEY = "age1gmc8dd4mj5q0zncy5gq4lccjlq9v84t8cqnlananmxt8g0jezv6szawll8"

# Rebuild sops-keys.nix, then rebuild .sops.yaml from repository layout.
def main [
  --check
  --update-secrets
  --verbose
] {
  log set-level (if $verbose { 10 } else { 20 })
  $env.NU_LOG_FORMAT = "%ANSI_START%%LEVEL%|%MSG%%ANSI_STOP%"

  let hosts = discover-hosts
  let users = discover-users
  let homes = discover-home-keys $users
  let age_keys = {
    deployer: $DEPLOYER_AGE_KEY
    homes: $homes
    hosts: $hosts
  }
  let always_present_age_keys = get-always-present-age-keys $homes
  let rendered_keys = render-age-keys $age_keys
  let rendered_sops = render-config $hosts $users $always_present_age_keys
  let keys_path = ($env.GIT_ROOT | path join $AGE_KEYS_FILE)
  let sops_path = ($env.GIT_ROOT | path join $SOPS_FILE)
  let current_keys = if ($keys_path | path exists) { open --raw $keys_path } else { "" }
  let current_sops = if ($sops_path | path exists) { open --raw $sops_path } else { "" }
  let keys_changed = $current_keys != $rendered_keys
  let sops_changed = $current_sops != $rendered_sops

  if $check and $update_secrets {
    log error "--check cannot be combined with --update-secrets"
    exit 1
  }

  if not $keys_changed and not $sops_changed and not $update_secrets {
    log info $"($AGE_KEYS_FILE) and ($SOPS_FILE) are up to date"
    exit 0
  }

  if $check {
    if $keys_changed { log error $"($AGE_KEYS_FILE) is out of date" }
    if $sops_changed { log error $"($SOPS_FILE) is out of date" }
    exit 1
  }

  if $keys_changed {
    $rendered_keys | save --force $keys_path
    log info $"Updated ($AGE_KEYS_FILE)"
  }

  if $sops_changed {
    $rendered_sops | save --force $sops_path
    log info $"Updated ($SOPS_FILE)"
  }

  if $update_secrets {
    let secret_files = discover-sops-files
    update-secret-files $secret_files
  }

  log info $"Processed ($hosts | length) hosts and ($users | length) users"
}

def discover-hosts [] {
  let hosts_root = ($env.GIT_ROOT | path join "hosts")
  glob ($hosts_root | path join "*" "*" $HOST_KEY_FILE)
    | each {|key_path|
      let host_dir = ($key_path | path dirname)
      let relative_dir = ($host_dir | path relative-to $env.GIT_ROOT)
      {
        type: ($relative_dir | path dirname | path basename)
        name: ($host_dir | path basename)
        recipient: (convert-public-key $key_path)
      }
    }
    | sort-by type name
}

def discover-users [] {
  let home_root = ($env.GIT_ROOT | path join "home")
  glob ($home_root | path join "*")
    | where {|user_dir|
      ($user_dir | path type) == "dir" and ($user_dir | path basename) != "shared"
    }
    | each {|user_dir| $user_dir | path basename }
    | sort
}

def discover-home-keys [users: list<string>] {
  mut homes = []
  for user in $users {
    let key_path = ($env.GIT_ROOT | path join "home" $user $HOME_KEY_FILE)
    if ($key_path | path exists) {
      $homes = $homes | append {
        name: $user
        recipient: (convert-public-key $key_path)
      }
    }
  }
  $homes | sort-by name
}

# Recipients included in every SOPS creation rule, in stable priority order.
def get-always-present-age-keys [homes] {
  let personal_age_key = get-personal-age-key $homes
  [
    { name: "my-home-age-key", recipient: $personal_age_key }
    { name: "deployer-age-key", recipient: $DEPLOYER_AGE_KEY }
  ]
}

def get-personal-age-key [homes] {
  let personal = $homes | where name == $env.CURRENT_USER
  if ($personal | is-empty) {
    let key_path = ($env.GIT_ROOT | path join "home" $env.CURRENT_USER $HOME_KEY_FILE)
    log error $"Missing ($key_path); cannot identify current user age key"
    exit 1
  }
  $personal | get recipient | first
}

def discover-sops-files [] {
  cd $env.GIT_ROOT
  let candidates = ((glob "hosts/**") ++ (glob "home/**"))
    | where {|path| ($path | path type) == "file"}
    | sort

  $candidates
    | each {|file|
      try {
        let status = ^sops filestatus $file err> /dev/null | from json
        if $status.encrypted { $file } else { null }
      } catch {
        null
      }
    }
    | where {|file| $file != null}
}

def update-secret-files [secret_files: list<string>] {
  cd $env.GIT_ROOT
  if ($secret_files | is-empty) {
    log info "No encrypted SOPS files found"
    return
  }

  for file in $secret_files {
    log info $"Updating SOPS recipients in ($file)"
    try {
      ^sops updatekeys --yes $file
    } catch {|err|
      log error $"Failed to update SOPS recipients in ($file): ($err)"
      exit 1
    }
  }
}

def convert-public-key [key_path: string] {
  try {
    let recipient = (open --raw $key_path | ^ssh-to-age | str trim)
    if ($recipient | is-empty) {
      error make {msg: $"No age recipient returned for ($key_path)"}
    }
    $recipient
  } catch {|err|
    log error $"Failed to convert public key ($key_path): ($err.msg)"
    exit 1
  }
}

def render-age-keys [age_keys] {
  let home_entries = $age_keys.homes
    | each {|home| $"    ($home.name) = \"($home.recipient)\";"}
    | str join "\n"
  let home_block = "  homes = {\n" + $home_entries + "\n  };\n"

  let host_types = $age_keys.hosts | get type | sort | uniq
  mut host_blocks = []
  for host_type in $host_types {
    let host_entries = $age_keys.hosts
      | where type == $host_type
      | sort-by name
      | each {|host| $"      ($host.name) = \"($host.recipient)\";"}
      | str join "\n"
    $host_blocks = $host_blocks | append ("    " + $host_type + " = {\n" + $host_entries + "\n    };")
  }
  let hosts_block = "  hosts = {\n" + ($host_blocks | str join "\n") + "\n  };\n"

  let output = "{\n" + $"  deployer = \"($age_keys.deployer)\";\n" + $home_block + $hosts_block + "}\n"
  $output
}

def render-config [
  hosts: list<record<type: string, name: string, recipient: string>>
  users: list<string>
  always_present_age_keys: list<record<name: string, recipient: string>>
] {
  let always_present_recipients = $always_present_age_keys | get recipient
  let all_host_keys = $hosts | get recipient
  let server_keys = $hosts | where type == "server" | get recipient
  mut rules = [
    (render-rule "hosts/secrets.yaml$" ($always_present_recipients ++ $all_host_keys))
    (render-rule "hosts/server/secrets.yaml$" ($always_present_recipients ++ $server_keys))
  ]

  for user in $users {
    $rules = $rules | append (render-rule $"home/($user)/secrets.yaml$" $always_present_recipients)
  }

  for host in $hosts {
    $rules = $rules | append (render-rule $"hosts/($host.type)/($host.name)/" ($always_present_recipients ++ [ $host.recipient ]))
  }

  let rendered_rules = $rules | str join "\n"
  $"creation_rules:\n($rendered_rules)\n"
}

def render-rule [path_regex: string, recipients: list<string>] {
  let age_entries = $recipients
    | uniq
    | each {|recipient| $"          - ($recipient)"}
    | str join "\n"

  $"  - path_regex: ($path_regex)\n    key_groups:\n      - age:\n($age_entries)"
}
