#!/usr/bin/env nu

use std/log

# Create or update a GitHub Pull Request
#
# If a PR already exists for the given branch and base, it will be updated.
# Otherwise, a new PR will be created.
#
# Required environment variables:
#   GITHUB_TOKEN     - GitHub token with contents:write and pull-requests:write scopes
#
# Returns:
#   0 on success, non-zero on failure
#   Outputs the PR number on success
def main [
  --branch: string            # Branch name to create PR from
  --title: string             # PR title
  --body: string              # PR body/description
  --base: string              # Base branch to merge into
  --labels: string = ""     # Comma-separated list of labels
  --assignees: string = ""  # Comma-separated list of assignees
  --reviewers: string = ""  # Comma-separated list of reviewers
  --draft                   # Create as draft PR
] {
  let github_token = $env.GITHUB_TOKEN? | default ""
  if ($github_token | is-empty) {
    log error "Error: GITHUB_TOKEN environment variable is required"
    exit 1
  }

  let existing_pr = gh pr list --head $branch --base $base --state open --json number
    | from json
    | get 0?.number?
    | default ""

  if not ($existing_pr | is-empty) {
    log info $"PR #($existing_pr) already exists, updating..."

    mut args = [
      "--title"
      $title
      "--body"
      $body
    ]

    if not ($labels | is-empty) {
      $args = $args | append ["--add-label" $labels]
    }

    if not ($assignees | is-empty) {
      $args = $args | append ["--add-assignee" $assignees]
    }

    if not ($reviewers | is-empty) {
      $args = $args | append ["--add-reviewer" $reviewers]
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
      let label_list = $labels | split row ","
      for label in $label_list {
        $args = ($args | append ["--label" $label])
      }
    }

    if not ($assignees | is-empty) {
      $args = ($args | append ["--assignee" $assignees])
    }

    if not ($reviewers | is-empty) {
      $args = ($args | append ["--reviewer" $reviewers])
    }

    let pr_url = run-external "gh" ...$args
    let pr_number = $pr_url | parse --regex '(\d+)$' | get 0?.capture0? | default ""

    print $pr_number
  }
}
