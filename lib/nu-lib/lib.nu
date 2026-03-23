use std/log

# Code ran at import time
export-env {
  setup_logging
}

# Setup logging level and format
#
# Environment variables:
#   VERBOSE
export def --env setup_logging [] {
  log set-level (if $env.DEBUG? == true { 10 } else { 20 })
  log info $"Logging initialized. Level: ($env.NU_LOG_LEVEL)"
  $env.NU_LOG_FORMAT = "%ANSI_START%%LEVEL%|%MSG%%ANSI_STOP%"
}

# Checks if the provided variables are available from the environment.
export def check_required_vars [
  --exit            # If the required vars aren't present exit the script with code 0
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
