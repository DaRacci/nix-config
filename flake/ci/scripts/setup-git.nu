#!/usr/bin/env nu

use std/log

const GIT_DEFAULT_NAME = "Woodpecker CI"
const GIT_DEFAULT_EMAIL = "woodpecker@racci.dev"

# The GPG Setup component is based on the crazy-max/ghaction-import-gpg github action.
# Reference: https://github.com/crazy-max/ghaction-import-gpg
export def setup-gpg [] {
  let gpg_private_key = $env.GPG_PRIVATE_KEY? | default ""
  let gpg_fingerprint = $env.GPG_FINGERPRINT? | default ""
  let gpg_passphrase = $env.GPG_PASSPHRASE? | default ""

  if ($gpg_private_key | is-empty) or ($gpg_fingerprint | is-empty) {
    log info "GPG credentials not provided, skipping GPG signing setup."
    return true # Not an error, just skipping
  }

  log info "Setting up GPG signing..."

  let gpg_home = if ($env.GNUPGHOME? | default "" | is-empty) {
    $"($env.HOME)/.gnupg"
  } else {
    $env.GNUPGHOME
  }

  let temp_key_file = (mktemp)
  mut import_result = { }
  try {
    let is_armored = ($gpg_private_key | str starts-with "-----BEGIN PGP")

    if $is_armored {
      log debug "Key is armored, importing directly"
      $gpg_private_key | save --force $temp_key_file
    } else {
      log debug "Key appears to be base64 encoded, decoding..."
      try {
        let decoded = ($gpg_private_key | decode base64 | decode)
        if ($decoded | str starts-with "-----BEGIN PGP") {
          log debug "Decoded key is armored text"
          $decoded | save --force $temp_key_file
        } else {
          log debug "Decoded key is binary data"
          $decoded | save --force --raw $temp_key_file
        }
      } catch {
        log warning "Failed to decode base64, trying to import as-is"
        $gpg_private_key | save --force $temp_key_file
      }
    }

    chmod 600 $temp_key_file

    $import_result = (gpg --batch --yes --import $temp_key_file | complete)
    if $import_result.exit_code != 0 {
      log error $"Failed to import GPG key: ($import_result.stderr)"
      rm -f $temp_key_file
      return false
    }

    log debug $"GPG key import output: ($import_result.stderr)"
    log debug "GPG key imported successfully"
  } catch {|e|
    log error $"Failed to import GPG key: ($e.msg)"
    rm -f $temp_key_file
    return false
  }

  rm -f $temp_key_file

  log debug "Verifying imported key..."
  let list_keys_result = (gpg --batch --list-secret-keys --with-colons | complete)
  if $list_keys_result.exit_code != 0 {
    log error $"Failed to list secret keys: ($list_keys_result.stderr)"
    return false
  }

  let fingerprint_clean = ($gpg_fingerprint | str replace --all " " "")
  let key_found = ($list_keys_result.stdout | str contains $fingerprint_clean)

  if not $key_found {
    log error $"Key with fingerprint ($fingerprint_clean) not found in keyring after import"
    log debug $"Available keys:\n($list_keys_result.stdout)"
    return false
  }

  log debug $"Key ($fingerprint_clean) verified in keyring"

  let primary_key_id = if ($import_result.stderr | str contains "key ") {
    let key_line = ($import_result.stderr | lines | where { |line| $line =~ "key [A-F0-9]+:" } | first | default "")
    if not ($key_line | is-empty) {
      $key_line | str replace --regex ".*key ([A-F0-9]+):.*" "$1"
    } else {
      let sec_line = ($list_keys_result.stdout | lines | where { |line| $line starts-with "sec:" } | first | default "")
      if not ($sec_line | is-empty) {
        $sec_line | split row ":" | get 4
      } else {
        $fingerprint_clean
      }
    }
  } else {
    $fingerprint_clean
  }

  log debug $"Using signing key ID: ($primary_key_id)"

  if not ($gpg_passphrase | is-empty) {
    log debug "Configuring gpg-agent for passphrase presetting..."

    let agent_conf = $"($gpg_home)/gpg-agent.conf"
    let agent_config = [
      "default-cache-ttl 21600"
      "max-cache-ttl 31536000"
      "allow-preset-passphrase"
    ] | str join "\n"

    $agent_config | save --force $agent_conf

    try {
      gpg-connect-agent "RELOADAGENT" /bye | complete | ignore
      log debug "gpg-agent reloaded successfully"
    } catch {
      log warning "Failed to reload gpg-agent, continuing anyway..."
    }

    let keygrips_result = (gpg --batch --with-colons --with-keygrip --list-secret-keys $primary_key_id | complete)
    if $keygrips_result.exit_code == 0 {
      let keygrips = ($keygrips_result.stdout | lines | where { |line| $line starts-with "grp:" } | each { |line| $line | split row ":" | get 9 })

      if ($keygrips | length) > 0 {
        let hex_passphrase = ($gpg_passphrase | encode utf-8 | encode hex | str upcase)
        for keygrip in $keygrips {
          try {
            let preset_cmd = $"PRESET_PASSPHRASE ($keygrip) -1 ($hex_passphrase)"
            gpg-connect-agent $preset_cmd /bye | complete | ignore
            log debug $"Passphrase preset for keygrip: ($keygrip)"
          } catch {
            log warning $"Failed to preset passphrase for keygrip: ($keygrip)"
          }
        }

        log debug $"Passphrase preset for ($keygrips | length) keygrip\(s)"
      } else {
        log warning "No keygrips found for the GPG key"
      }
    } else {
      log warning $"Failed to get keygrips: ($keygrips_result.stderr)"
    }
  }

  git config --global commit.gpgsign true
  git config --global user.signingkey $primary_key_id
  git config --global tag.gpgsign true
  git config --global gpg.program (which gpg | get path.0)
  log info $"GPG signing configured with key ($primary_key_id)"


  log debug "Testing GPG signing to verify key setup..."
  let test_message = "GPG signing test"
  let test_sign_result = if not ($gpg_passphrase | is-empty) {
    echo $test_message | gpg --pinentry-mode loopback --passphrase $gpg_passphrase --batch --yes --armor --detach-sign --local-user $primary_key_id | complete
  } else {
    echo $test_message | gpg --batch --yes --armor --detach-sign --local-user $primary_key_id | complete
  }

  if $test_sign_result.exit_code != 0 {
    log error $"GPG test signing failed: ($test_sign_result.stderr)"
    log error "The GPG key was imported but cannot sign. Please check the passphrase and key configuration."
    return false
  }

  let temp_msg = (mktemp)
  let temp_sig = (mktemp)
  try {
    $test_message | save --force $temp_msg
    $test_sign_result.stdout | save --force $temp_sig

    let test_verify_result = (gpg --batch --verify $temp_sig $temp_msg | complete)
    if $test_verify_result.exit_code != 0 {
      log warning $"GPG signature verification had issues: ($test_verify_result.stderr)"
      # Note: GPG verification might show warnings even on success, so we don't fail here
    } else {
      log debug "GPG test signing and verification successful"
    }
  } catch {
    log warning "Failed to verify test signature, but signing worked"
  }

  # Clean up temp files
  rm -f $temp_msg $temp_sig

  log info "GPG signing setup complete and verified"
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
