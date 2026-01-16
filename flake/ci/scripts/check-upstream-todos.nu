#!/usr/bin/env nu
# This is heavily based off https://github.com/pinpox/nixos/blob/main/.github/workflows/check-upstream-todos.yml

use std/log

const TODO_PATTERN = "TODO:?\\s*https://github\\.com/[^/]+/[^/]+/(pull|issues)/[0-9]+"
const URL_PATTERN = "https://github\\.com/[^/]+/[^/]+/(pull|issues)/[0-9]+"
const URL_CAPTURE = "^https://github\\.com/(?<owner>[^/]+)/(?<repo>[^/]+)/(?<type>pull|issues)/(?<number>[0-9]+)$"

def collect-todo-entries [] {
  let args = [
    "--line-number"
    "--no-heading"
    "--color=never"
    "--hidden"
    "--glob" "!.git/**"
    "--glob" "!.github/**"
    "--pcre2"
    "--regexp" $TODO_PATTERN
    "."
  ]

  let output = (try { run-external "rg" ...$args } catch { "" }) | str trim

  if ($output | is-empty) {
    []
  } else {
    $output
    | lines
    | where { |line| not ($line | str trim | is-empty) }
    | each { |line|
        let parsed = (
          $line
          | parse --regex "^(?<path>[^:]+):(?<line>\\d+):(?<content>.*)$"
          | get 0?
          | default null
        )

        if $parsed == null {
          null
        } else {
          {
            raw: $line
            path: $parsed.path
            line: ($parsed.line | into int)
            content: ($parsed.content | str trim)
          }
        }
      }
    | where { |entry| $entry != null }
  }
}

def extract-urls [text: string] {
  let matches = (
    try { echo $text | rg --only-matching --color=never --pcre2 $URL_PATTERN } catch { "" }
  ) | str trim

  if ($matches | is-empty) {
    []
  } else {
    $matches
    | lines
    | where { |line| not ($line | str trim | is-empty) }
    | sort
    | uniq
  }
}

def build-url-map [entries: list<record>] {
  mut map = {}

  for entry in $entries {
    let urls = extract-urls $entry.content
    if ($urls | is-empty) {
      continue
    }

    for url in $urls {
      let location = {
        path: $entry.path
        line: $entry.line
        content: $entry.content
      }

      let existing = $map | get -o $url | default []
      $map = ($map | upsert $url ($existing | append $location))
    }
  }

  $map
}

def truthy [value: any] {
  if ($value == true) {
    true
  } else if ($value == false) {
    false
  } else {
    let lowered = try { $value | into string | str downcase } catch { "" }
    $lowered == "true"
  }
}

def github-request [url: string, token: string] {
  mut args = [
    "--silent"
    "--show-error"
    "--location"
    "--header" "User-Agent: check-upstream-todos.nu"
    "--header" "Accept: application/vnd.github.v3+json"
  ]

  if not ($token | str trim | is-empty) {
    $args = $args | append ["--header" $"Authorization: Bearer ($token)"]
  }

  $args = $args | append $url

  let response = (run-external "curl" ...$args | complete)

  if $response.exit_code != 0 {
    let stderr_text = $response.stderr | default "" | str trim
    let message = if ($stderr_text | is-empty) { $"curl exited with status ($response.exit_code)" } else { $stderr_text }
    log warning $"  ⚠️  Could not query GitHub API: ($message)"
    return null
  }

  let body = $response.stdout | default "" | str trim
  if ($body | is-empty) {
    log warning "  ⚠️  GitHub API returned an empty response."
    return null
  }

  try { $body | from json } catch { |err|
    let err_msg = $err.msg? | default ($err | into string)
    log warning $"  ⚠️  Failed to parse GitHub API response: ($err_msg)"
    null
  }
}

def print-locations [locations: list<record>] {
  if ($locations | is-empty) {
    log info "    (no recorded locations)"
  } else {
    for location in $locations {
      log info $"    ($location.path):($location.line): ($location.content)"
    }
  }
}

def handle-pull [owner repo number github_token locations] {
  log info $"  Checking PR #($number) in ($owner)/($repo)..."
  let api_url = $"https://api.github.com/repos/($owner)/($repo)/pulls/($number)"
  let response = github-request $api_url $github_token

  if $response == null {
    log warning "  ⚠️  Could not determine PR status."
    return false
  }

  let state_raw = $response.state? | default "unknown"
  let state = try { $state_raw | into string | str downcase } catch { "unknown" }
  let merged_flag = truthy ($response.merged? | default false)

  if ($state == "closed") and $merged_flag {
    log error $"  ❌ FAIL: PR #($number) is MERGED! Remove TODO and workaround."
    log info "  Locations:"
    print-locations $locations
    true
  } else if ($state == "closed") {
    log warning $"  ⚠️  PR #($number) is closed but not merged."
    false
  } else if ($state == "open") {
    log info $"  ✅ PR #($number) is still open."
    false
  } else {
    log warning $"  ⚠️  Could not determine PR status (state: ($state_raw), merged: ($merged_flag))."
    false
  }
}

def handle-issue [owner repo number github_token locations] {
  log info $"  Checking Issue #($number) in ($owner)/($repo)..."
  let api_url = $"https://api.github.com/repos/($owner)/($repo)/issues/($number)"
  let response = github-request $api_url $github_token

  if $response == null {
    log warning "  ⚠️  Could not determine issue status."
    return false
  }

  let state_raw = $response.state? | default "unknown"
  let state = try { $state_raw | into string | str downcase } catch { "unknown" }

  if $state == "closed" {
    log error $"  ❌ FAIL: Issue #($number) is CLOSED! Remove TODO and workaround."
    log info "  Locations:"
    print-locations $locations
    true
  } else if $state == "open" {
    log info $"  ✅ Issue #($number) is still open."
    false
  } else {
    log warning $"  ⚠️  Could not determine issue status (state: ($state_raw))."
    false
  }
}

def main [] {
  let github_token = $env.GITHUB_TOKEN? | default ""
  let root_dir = try { git rev-parse --show-toplevel | str trim } catch { "." }
  cd $root_dir

  log info "Searching for TODO comments with GitHub links..."

  let entries = collect-todo-entries
  if ($entries | is-empty) {
    log info "No TODO comments with GitHub links found."
    return
  }

  log info "Found TODO comments:"
  $entries | each { |entry| print $entry.raw }
  print ""

  let url_map = build-url-map $entries
  let urls = $url_map | columns | sort

  if ($urls | is-empty) {
    log info "No GitHub URLs extracted from TODO comments."
    return
  }

  mut failed = false
  mut failures = []

  for url in $urls {
    log info $"Checking: ($url)"

    let locations = $url_map | get -o $url | default []
    let parsed = (
      $url
      | parse --regex $URL_CAPTURE
      | get 0?
      | default null
    )

    if $parsed == null {
      log warning "  ⚠️  Could not parse URL."
      print ""
      continue
    }

    let owner = $parsed.owner
    let repo = $parsed.repo
    let kind = $parsed.type
    let number = $parsed.number

    let was_failure = if $kind == "pull" {
      handle-pull $owner $repo $number $github_token $locations
    } else {
      handle-issue $owner $repo $number $github_token $locations
    }

    if $was_failure {
      $failed = true
      let summary = $locations | each { |loc| $"($loc.path):($loc.line): ($loc.content)" }
      $failures = ($failures | append { url: $url, locations: $summary })
    }

    print ""
  }

  if $failed {
    log error "❌ One or more upstream issues/PRs have been resolved!"
    log info ""
    log info "Summary of resolved TODOs:"

    for entry in $failures {
      log info $"  URL: ($entry.url)"
      if ($entry.locations | is-empty) {
        log info "    (no recorded locations)"
      } else {
        for loc in $entry.locations {
          log info $"    ($loc)"
        }
      }
      log info ""
    }

    exit 1
  } else {
    log info "✅ All upstream issues/PRs are still unresolved."
  }
}
