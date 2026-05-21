use std/log

# Code ran at import time
export-env {
  setup_logging $env.DEBUG? $env.SILENT?
}

# Setup logging level and format
#
# Environment variables:
#   DEBUG: set to "true" to enable debug logging
#   SILENT: set to "true" to suppress logging
export def --env setup_logging [debug: string = "", silent: string = ""] {
  log set-level (
    if $debug == "true" { 10 }
    else if $silent == "true" { 40 }
    else { 20 }
  )
  log info $"Logging initialized. Level: ($env.NU_LOG_LEVEL)"
  $env.NU_LOG_FORMAT = "%ANSI_START%%LEVEL%|%MSG%%ANSI_STOP%"
}

# Checks if the provided variables are available from the environment.
export def check_required_vars [
  --exit            # If the required vars aren't present exit the script with code 1
  ...vars: string   # The variables to look for.
] {
  mut missing_vars = [ ];
  for var in $vars {
    let value = $env | get -o $var
    log debug $"Checking required variable of [($var)] - present: \(($value != null)\)"
    if $value == null {
      $missing_vars = $missing_vars | append $var
    }
  }

  let result = (($missing_vars | length) > 0)

  if $result and $exit {
    log debug $"Exiting early due to missing vars ($missing_vars | str join ",")"
    exit 1
  }

  return $result
}

# Quote segments of a nix attribute path to handle special characters
# e.g. "my-attr" becomes "\"my-attr\"".
#
# This will split the input string by dots, quote each segment, and then rejoin them with dots.
# If a segment is quoted already, it will be kept as is.
# Preserves .# flake references at the start.
export def quote_nix_segments [attribute_path: string] {
  let has_flake_ref = $attribute_path | str starts-with ".#"
  let path_to_process = if $has_flake_ref { $attribute_path | str substring 2.. } else { $attribute_path }

  let chars = $path_to_process | split chars
  let result = $chars | reduce -f {segments: [], current: "", in_quotes: false} {|char, acc|
    if $char == '"' {
      {segments: $acc.segments, current: ($acc.current + $char), in_quotes: (not $acc.in_quotes)}
    } else if $char == "." and not $acc.in_quotes {
      {segments: ($acc.segments | append $acc.current), current: "", in_quotes: $acc.in_quotes}
    } else {
      {segments: $acc.segments, current: ($acc.current + $char), in_quotes: $acc.in_quotes}
    }
  }

  let all_segments = $result.segments | append $result.current
  let quoted = $all_segments | each {|s|
    if (($s | str starts-with '"') and ($s | str ends-with '"')) { $s } else { '"' + $s + '"' }
  }

  let final = $quoted | str join "."
  if $has_flake_ref { ".#" + $final } else { $final }
}
