#!/usr/bin/env nu

use std/log

const GIT_DEFAULT_NAME = "Woodpecker CI"
const GIT_DEFAULT_EMAIL = "woodpecker@racci.dev"

export def setup-gpg [] {
  let gpg_private_key = $env.GPG_PRIVATE_KEY? | default ""
  let gpg_fingerprint = $env.GPG_FINGERPRINT? | default ""
  let gpg_passphrase = $env.GPG_PASSPHRASE? | default ""

  if ($gpg_private_key | is-empty) or ($gpg_fingerprint | is-empty) {
    log info "GPG credentials not provided, skipping GPG signing setup."
    return true # Not an error, just skipping
  }

  log info "Setting up GPG signing..."

  $gpg_private_key | gpg --batch --import

  # If a passphrase is provided, unlock the key by signing a dummy message
  if not ($gpg_passphrase | is-empty) {
    try {
      $gpg_passphrase | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --sign --local-user $gpg_fingerprint --output /dev/null /dev/null
    } catch {
      log debug "GPG key unlock attempt completed (may have failed, which is acceptable)"
    }
  }

  git config --global commit.gpgsign true
  git config --global user.signingkey $gpg_fingerprint

  log info $"GPG signing configured with key ($gpg_fingerprint)"
  true
}

export def setup-user [
  --name: string
  --email: string
] {
  let user_name = if ($name | is-empty) { $env.GIT_USER_NAME? | default $GIT_DEFAULT_NAME } else { $name }
  let user_email = if ($email | is-empty) { $env.GIT_USER_EMAIL? | default $GIT_DEFAULT_EMAIL } else { $email }

  if ($user_name | is-empty) or ($user_email | is-empty) {
    log warning "Git user name or email not provided, skipping user setup."
    return true # Not an error, just skipping
  }

  log info $"Configuring git user: ($user_name) <($user_email)>"

  git config --global user.name $user_name
  git config --global user.email $user_email

  true
}

# Setup GitHub credential helper for HTTPS authentication
export def setup-github-credentials [] {
  let github_token = $env.GITHUB_TOKEN? | default ""

  if ($github_token | is-empty) {
    log info "GITHUB_TOKEN not provided, skipping credential helper setup."
    return true # Not an error, just skipping
  }

  log info "Setting up GitHub credential helper..."

  git config --global credential.helper store
  git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"

  true
}

export def setup-git [
  --name: string
  --email: string
] {
  log info "Setting up git for CI..."

  let user_configured = setup-user --name $name --email $email
  let gpg_configured = setup-gpg
  let credentials_configured = setup-github-credentials

  let status = {
    user: $user_configured
    gpg: $gpg_configured
    credentials: $credentials_configured
  }

  log info $"Git setup complete: user=($user_configured), gpg=($gpg_configured), credentials=($credentials_configured)"

  $status
}

# Setup git for CI pipelines including user config, GPG signing, and credentials.
#
# Required environment variables:
#   GIT_USER_NAME    - Git user name for commits
#   GIT_USER_EMAIL   - Git user email for commits
#
# Optional environment variables (for GPG signing):
#   GPG_PRIVATE_KEY  - The GPG private key (armor format)
#   GPG_FINGERPRINT  - The GPG key fingerprint
#   GPG_PASSPHRASE   - The GPG key passphrase (if key is protected)
#
# Optional environment variables (for authentication):
#   GITHUB_TOKEN     - GitHub token for HTTPS authentication with scopes: contents:write
def main [
  --name: string
  --email: string
] {
  let status = setup-git --name $name --email $email

  if not ($status.user and $status.credentials and $status.gpg) {
    exit 1
  }
}
