#!/usr/bin/env nu

use std/log
use lib/common.nu
use lib/flake.nu *

def main [
  workflow_file: string,                    # The path to the woodpecker workflow file
  matrix_key: string,                       # The key of the matrix to update (e.g., "USERS")
  eval_expression: string,                   # The nix expression path to get the list of entries to use for the matrix (e.g., "nixosConfigurations")
  eval_apply: string = "builtins.attrNames" # The nix expression to apply to the evaluated entries to get the final list (default: builtins.attrNames)
] {
  if (not ($workflow_file | path exists)) {
    log error $"Workflow file ($workflow_file) does not exist"
    exit 1
  }

  let yaml = open $workflow_file
  if ($yaml | describe -d | get type) != "record" {
    log error $"Workflow file ($workflow_file) is not a valid YAML record"
    exit 1
  }

  if (
    (($yaml | get --optional matrix) == null)
    or (($yaml.matrix | get --optional $matrix_key) == null)
  ) {
    log error $"Workflow file ($workflow_file) does not contain a matrix with key ($matrix_key)"
    exit 1
  }

  let current_matrix = $yaml.matrix | get $matrix_key
  log info $"Current matrix for key ($matrix_key): ($current_matrix)"

  let eval_entries = nix eval --json $eval_expression --apply $eval_apply | from json
  if ($eval_entries | describe -d | get type) != "list" {
    log error $"Evaluated expression ($eval_expression) with apply ($eval_apply) did not return a list"
    exit 1
  }

  let new_matrix = $eval_entries | sort | uniq
  log info $"New matrix for key ($matrix_key): ($new_matrix)"

  if $new_matrix == $current_matrix {
    log info "Matrix is up to date, no changes needed"
    exit 0
  }

  replace_matrix $workflow_file $matrix_key $new_matrix
  log info $"Updated workflow file ($workflow_file) with new matrix for key ($matrix_key)"
}

# Replace only the matrix key's lines, leaving the rest of the file untouched.
def replace_matrix [
  workflow_file: string
  matrix_key: string
  values: list<string>
] {
  let lines = (open --raw $workflow_file | lines)
  let key_re = $"^\\s*($matrix_key):\\s*.*$"
  let total = ($lines | length)

  mut out = [ ]
  mut i = 0
  mut in_matrix = false

  while $i < $total {
    let line = ($lines | get $i)

    if $line =~ "^matrix:\\s*$" {
      $in_matrix = true
      $out = ($out | append $line)
      $i = $i + 1
      continue
    }

    if $in_matrix {
      let trimmed = ($line | str trim)
      if not ($trimmed | is-empty) {
        let indent = (($line | str length) - ($line | str trim --left | str length))

        if $indent == 0 {
          $in_matrix = false
        } else if ($line =~ $key_re) {
          let indent_str = (" " | fill --width $indent)
          let item_indent = (" " | fill --width ($indent + 2))
          let items = ($values | each { |value| $item_indent + "- " + $value })

          $out = ($out | append ($indent_str + $matrix_key + ":"))
          $out = ($out ++ $items)

          # Skip the old list items.
          $i = $i + 1
          while $i < $total {
            let next = ($lines | get $i)
            let next_trimmed = ($next | str trim)
            if ($next_trimmed | is-empty) { break }
            let next_indent = (($next | str length) - ($next | str trim --left | str length))
            if $next_indent <= $indent { break }
            $i = $i + 1
          }
          continue
        }
      }
    }

    $out = ($out | append $line)
    $i = $i + 1
  }

  ($out | str join "\n") + "\n" | save --force $workflow_file
}
