#!/usr/bin/env nu

use std/log
use lib/common.nu

# Create or update a pull request on the active forge.
#
# Uses the GitHub CLI when `CI_FORGE_TYPE` is `github`, and the Forgejo/Gitea
# API otherwise. Required environment variables:
#   FORGE_TOKEN      - token with repository and pull-request write access
#                      (falls back to GITHUB_TOKEN)
#   CI_FORGE_URL     - forge root URL (defaults to https://codeberg.org)
#   CI_REPO          - owner/repo (defaults to CI_REPO_OWNER/CI_REPO_NAME)
#
# Returns the pull request number on success.
def main [
  --branch: string            # Branch name to create PR from
  --title: string             # PR title
  --body: string              # PR body/description
  --base: string              # Base branch to merge into
  --labels: string = ""       # Comma-separated list of labels
  --assignees: string = ""    # Comma-separated list of assignees
  --reviewers: string = ""    # Comma-separated list of reviewers
  --draft                     # Create as draft PR
] {
  let token = ($env.FORGE_TOKEN? | default ($env.GITHUB_TOKEN? | default ""))
  if ($token | is-empty) {
    log error "FORGE_TOKEN (or GITHUB_TOKEN) environment variable is required"
    exit 1
  }

  let forge = ($env.CI_FORGE_TYPE? | default "forgejo")
  if $forge == "github" {
    create-github $token $branch $title $body $base $labels $assignees $reviewers $draft
  } else {
    create-forgejo $token $branch $title $body $base $labels $assignees $reviewers $draft
  }
}

def create-github [
  token: string
  branch: string
  title: string
  body: string
  base: string
  labels: string
  assignees: string
  reviewers: string
  draft: bool
] {
  with-env { GH_TOKEN: $token } {
    let existing_pr = (gh pr list --head $branch --base $base --state open --json number
      | from json
      | get 0?.number?
      | default "")

    if not ($existing_pr | is-empty) {
      log info $"PR #($existing_pr) already exists, updating..."

      mut args = [
        "--title"
        $title
        "--body"
        $body
      ]

      if not ($labels | is-empty) {
        $args = ($args | append [ "--add-label" $labels ])
      }

      if not ($assignees | is-empty) {
        $args = ($args | append [ "--add-assignee" $assignees ])
      }

      if not ($reviewers | is-empty) {
        $args = ($args | append [ "--add-reviewer" $reviewers ])
      }

      gh pr edit $existing_pr ...$args
      print $existing_pr
    } else {
      log info "Creating new PR..."

      mut args = [
        "pr" "create"
        "--head" $branch
        "--base" $base
        "--title" $title
        "--body" $body
      ]

      if $draft {
        $args = ($args | append "--draft")
      }

      if not ($labels | is-empty) {
        let label_list = ($labels | split row ",")
        for label in $label_list {
          $args = ($args | append [ "--label" $label ])
        }
      }

      if not ($assignees | is-empty) {
        $args = ($args | append [ "--assignee" $assignees ])
      }

      if not ($reviewers | is-empty) {
        $args = ($args | append [ "--reviewer" $reviewers ])
      }

      gh ...$args
    }
  }
}

def create-forgejo [
  token: string
  branch: string
  title: string
  body: string
  base: string
  labels: string
  assignees: string
  reviewers: string
  draft: bool
] {
  let forge_url = (($env.CI_FORGE_URL? | default "https://codeberg.org") | str trim --right --char '/')
  let repo = (
    $env.CI_REPO?
    | default ([
        ($env.CI_REPO_OWNER? | default "Racci")
        ($env.CI_REPO_NAME? | default "nix-config")
      ] | str join "/")
  )
  let api = $"($forge_url)/api/v1/repos/($repo)"
  let auth = $"Authorization: token ($token)"

  let existing = (curl --fail --silent --show-error -H $auth $"($api)/pulls?state=open&limit=50"
    | from json
    | where { |pr| $pr.head.ref == $branch and $pr.base.ref == $base }
    | get 0?.number?
    | default "")

  let index = if ($existing | is-empty) {
    let payload = ({
      head: $branch
      base: $base
      title: $title
      body: $body
      draft: $draft
    } | to json)

    let created = (curl --fail --silent --show-error -X POST -H $auth -H "Content-Type: application/json" -d $payload $"($api)/pulls" | from json)

    log info $"Created PR #($created.number)"
    $created.number
  } else {
    let payload = ({ title: $title, body: $body } | to json)
    curl --fail --silent --show-error -X PATCH -H $auth -H "Content-Type: application/json" -d $payload $"($api)/pulls/($existing)" | ignore
    log info $"Updated PR #($existing)"
    $existing
  }

  if not ($labels | is-empty) {
    try-add-labels $api $auth $index $labels
  }
  if not ($assignees | is-empty) {
    try-add-assignees $api $auth $index $assignees
  }
  if not ($reviewers | is-empty) {
    try-request-reviewers $api $auth $index $reviewers
  }

  print $index
}

def try-add-labels [
  api: string
  auth: string
  index: int
  labels: string
] {
  let wanted = ($labels | split row "," | each { |label| $label | str trim } | where { |label| not ($label | is-empty) })
  try {
    let available = (curl --fail --silent --show-error -H $auth $"($api)/labels?limit=100" | from json)
    let ids = ($wanted
      | each { |name| $available | where { |label| $label.name == $name } | get 0?.id? }
      | where { |id| $id != null })

    if ($ids | is-empty) {
      log warning $"No matching labels found for ($labels)"
      return
    }

    let payload = ({ labels: $ids } | to json)
    curl --fail --silent --show-error -X POST -H $auth -H "Content-Type: application/json" -d $payload $"($api)/issues/($index)/labels" | ignore
  } catch { |err|
    log warning $"Failed to add labels: ($err.msg)"
  }
}

def try-add-assignees [
  api: string
  auth: string
  index: int
  assignees: string
] {
  let users = ($assignees | split row "," | each { |user| $user | str trim } | where { |user| not ($user | is-empty) })
  let payload = ({ assignees: $users } | to json)
  try {
    curl --fail --silent --show-error -X PATCH -H $auth -H "Content-Type: application/json" -d $payload $"($api)/issues/($index)" | ignore
  } catch { |err|
    log warning $"Failed to add assignees: ($err.msg)"
  }
}

def try-request-reviewers [
  api: string
  auth: string
  index: int
  reviewers: string
] {
  let users = ($reviewers | split row "," | each { |user| $user | str trim } | where { |user| not ($user | is-empty) })
  let payload = ({ reviewers: $users } | to json)
  try {
    curl --fail --silent --show-error -X POST -H $auth -H "Content-Type: application/json" -d $payload $"($api)/pulls/($index)/requested_reviewers" | ignore
  } catch { |err|
    log warning $"Failed to request reviewers: ($err.msg)"
  }
}
