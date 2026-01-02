#!/usr/bin/env nu

# Create or update a GitHub Pull Request from Woodpecker CI pipelines.
#
# Required environment variables:
#   GITHUB_TOKEN     - GitHub token with contents:write and pull-requests:write scopes
#
# Required arguments:
#   --branch         - The branch name to create the PR from
#   --title          - The PR title
#   --body           - The PR body/description
#
# Optional arguments:
#   --base           - The base branch to merge into (default: main)
#   --labels         - Comma-separated list of labels to add
#   --assignees      - Comma-separated list of assignees
#   --reviewers      - Comma-separated list of reviewers
#   --draft          - Create as draft PR (flag, no value needed)
#
# Usage:
#   ./.woodpecker/scripts/create-pr.nu \
#     --branch "update/flake-lock" \
#     --title "Update flake.lock" \
#     --body "Automated update" \
#     --labels "dependencies,automated" \
#     --assignees "username"
#
# Returns:
#   0 on success, non-zero on failure
#   Outputs the PR number on success

use std/log

# Create or update a GitHub Pull Request
export def create-pr [
  --branch: string        # Branch name to create PR from (required)
  --title: string         # PR title (required)
  --body: string          # PR body/description (required)
  --base: string = "main" # Base branch to merge into
  --labels: string = ""   # Comma-separated list of labels
  --assignees: string = "" # Comma-separated list of assignees
  --reviewers: string = "" # Comma-separated list of reviewers
  --draft                 # Create as draft PR
] {
  # Validate required arguments
  if ($branch | is-empty) {
    log error "Error: --branch is required"
    exit 1
  }

  if ($title | is-empty) {
    log error "Error: --title is required"
    exit 1
  }

  if ($body | is-empty) {
    log error "Error: --body is required"
    exit 1
  }

  let github_token = $env.GITHUB_TOKEN? | default ""
  if ($github_token | is-empty) {
    log error "Error: GITHUB_TOKEN environment variable is required"
    exit 1
  }

  # Check if PR already exists for this branch
  let existing_pr = try {
    gh pr list --head $branch --base $base --json number | from json | get 0?.number? | default ""
  } catch {
    ""
  }

  if not ($existing_pr | is-empty) {
    log info $"PR #($existing_pr) already exists, updating..."

    # Update existing PR
    gh pr edit $existing_pr --title $title --body $body

    # Add labels if specified
    if not ($labels | is-empty) {
      let label_list = $labels | split row ","
      for label in $label_list {
        try {
          gh pr edit $existing_pr --add-label $label
        } catch {
          log debug $"Failed to add label ($label), may already exist"
        }
      }
    }

    print $existing_pr
  } else {
    log info "Creating new PR..."

    # Build the command arguments
    mut args = [
      "pr" "create"
      "--head" $branch
      "--base" $base
      "--title" $title
      "--body" $body
    ]

    # Add draft flag if specified
    if $draft {
      $args = ($args | append "--draft")
    }

    # Add labels
    if not ($labels | is-empty) {
      let label_list = $labels | split row ","
      for label in $label_list {
        $args = ($args | append ["--label" $label])
      }
    }

    # Add assignees
    if not ($assignees | is-empty) {
      $args = ($args | append ["--assignee" $assignees])
    }

    # Add reviewers
    if not ($reviewers | is-empty) {
      $args = ($args | append ["--reviewer" $reviewers])
    }

    # Create the PR and extract the number
    let pr_url = run-external "gh" ...$args
    let pr_number = $pr_url | parse --regex '(\d+)$' | get 0?.capture0? | default ""

    print $pr_number
  }
}

def main [
  --branch: string        # Branch name to create PR from (required)
  --title: string         # PR title (required)
  --body: string          # PR body/description (required)
  --base: string = "main" # Base branch to merge into
  --labels: string = ""   # Comma-separated list of labels
  --assignees: string = "" # Comma-separated list of assignees
  --reviewers: string = "" # Comma-separated list of reviewers
  --draft                 # Create as draft PR
] {
  create-pr --branch $branch --title $title --body $body --base $base --labels $labels --assignees $assignees --reviewers $reviewers --draft=$draft
}
