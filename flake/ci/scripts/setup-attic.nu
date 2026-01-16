#!/usr/bin/env nu

use std/log
use lib/lib.nu check_required_vars

const REQUIRED_VARS = [
  BINARY_CACHE_TOKEN
]

# Sets up the attic binary cache
#
# Required environment variables:
#   PLUGIN_BINARY_CACHE_TOKEN - Token for accessing the binary cache
def main [
  --watch # If a background process should be spawned to watch the nix store
] {
  log set-level 0
  check_required_vars --exit ...$REQUIRED_VARS

  $"machine cache.racci.dev\npassword ($env.BINARY_CACHE_TOKEN)" | save -f /tmp/netrc
  attic login raccidev https://cache.racci.dev/global $env.BINARY_CACHE_TOKEN

  if $watch {
    # No native way to disown a background job in nu so lets use bash
    bash -c "attic watch-store raccidev:global & disown"
  }
}
