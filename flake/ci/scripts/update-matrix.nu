use lib/flake.nu *
use std/log

def main [
  workflow_file: string,                    # The path to the woodpecker workflow file
  matrix_key: string,                       # The key of the matrix to update (e.g., "USERS")
  eval_expression: string,                   # The nix expression path to get the list of entries to use for the matrix (e.g., "nixosConfigurations")
  eval_apply: string = "builtins.attrNames" # The nix expression to apply to the evaluated entries to get the final list (default: "builtins.attrNames")
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

  let updated_yaml = $yaml | update $"matrix.($matrix_key)" $new_matrix
  let yaml_string = updated_yaml | to yaml

  yaml_string | save --force $workflow_file
  log info $"Updated workflow file ($workflow_file) with new matrix for key ($matrix_key)"
}
