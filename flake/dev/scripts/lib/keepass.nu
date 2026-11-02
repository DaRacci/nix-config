use std/log

# Resolve credentials once with `vault-credentials`,
# then pass the returned record to the attachment and PKI helpers.
# Optional path flags are typed `any` so callers can pass null when the flag is absent.

# Resolve and validate KeePassXC credentials from command-line options.
#
# Returns { path, password, password_file, key_file, no_password }.
export def vault-credentials [
  vault: path # KeePassXC database
  --password-file: any # File holding the vault password
  --key-file: any # KeePassXC key file for the vault
  --no-password # Unlock the vault with a key file only
  --prompt: string = "KeePassXC password: " # Prompt used when no password file is given
] {
  let vault_path = $vault | path expand
  if not ($vault_path | path exists) {
    error make { msg: $"Missing KeePassXC vault: ($vault_path)" }
  }

  let password_file = if $password_file == null { null } else { $password_file | path expand }
  let key_file = if $key_file == null { null } else { $key_file | path expand }

  if $password_file != null and not ($password_file | path exists) {
    error make { msg: $"Missing vault password file: ($password_file)" }
  }
  if $key_file != null and not ($key_file | path exists) {
    error make { msg: $"Missing vault key file: ($key_file)" }
  }
  if $no_password and $password_file != null {
    error make { msg: "A key-file-only vault cannot also use a password file" }
  }

  let password = if $no_password {
    null
  } else if $password_file != null {
    open --raw $password_file | str trim
  } else {
    let value = (input --suppress-output $prompt)
    if $value == "" {
      error make { msg: "Empty vault password; use --no-password for a key-file-only vault" }
    }
    $value
  }

  {
    path: $vault_path
    password: $password
    password_file: $password_file
    key_file: $key_file
    no_password: $no_password
  }
}

# Export an attachment from a KeePassXC entry.
export def vault-attachment [
  credentials: record # Result of `vault-credentials`
  entry: string # Entry path inside the vault
  attachment: string # Attachment name
  destination: path # File to write
] {
  let auth = if $credentials.no_password {
    ["--no-password"]
  } else {
    []
  }
  let key = if $credentials.key_file == null {
    []
  } else {
    ["--key-file" $credentials.key_file]
  }
  let args = ["attachment-export" "--quiet"] ++ $auth ++ $key ++ [
    $credentials.path
    $entry
    $attachment
    $destination
  ]

  rm -f $destination
  let result = if $credentials.no_password {
    ^keepassxc-cli ...$args | complete
  } else {
    $credentials.password | ^keepassxc-cli ...$args | complete
  }

  if $result.exit_code != 0 {
    error make {
      msg: $"Could not export ($attachment) from KeePassXC entry ($entry): ($result.stderr | str trim)"
    }
  }
  if not ($destination | path exists) {
    error make { msg: $"KeePassXC did not write attachment ($attachment) to ($destination)" }
  }
}

# Export an attachment and verify that it contains a PEM object.
export def vault-pem-attachment [
  credentials: record # Result of `vault-credentials`
  entry: string # Entry path inside the vault
  attachment: string # Attachment name
  destination: path # File to write
  --label: any = null # Expected PEM label, for example CERTIFICATE
] {
  vault-attachment $credentials $entry $attachment $destination

  let pem = open --raw $destination
  if not ($pem | str starts-with "-----BEGIN") {
    error make { msg: $"KeePassXC entry ($entry) attachment ($attachment) does not contain a PEM file" }
  }
  if $label != null and not ($pem | str contains $"-----BEGIN ($label)-----") {
    error make {
      msg: $"KeePassXC entry ($entry) attachment ($attachment) does not contain a PEM ($label)"
    }
  }
}

# Read a PEM attachment into memory without writing it to disk.
export def vault-pem-attachment-data [
  credentials: record # Result of `vault-credentials`
  entry: string # Entry path inside the vault
  attachment: string # Attachment name
  --label: any = null # Expected PEM label, for example PRIVATE KEY
] {
  let auth = if $credentials.no_password {
    ["--no-password"]
  } else {
    []
  }
  let key = if $credentials.key_file == null {
    []
  } else {
    ["--key-file" $credentials.key_file]
  }
  let args = ["attachment-export" "--quiet" "--stdout"] ++ $auth ++ $key ++ [
    $credentials.path
    $entry
    $attachment
  ]

  let result = if $credentials.no_password {
    ^keepassxc-cli ...$args | complete
  } else {
    $credentials.password | ^keepassxc-cli ...$args | complete
  }

  if $result.exit_code != 0 {
    error make {
      msg: $"Could not export ($attachment) from KeePassXC entry ($entry): ($result.stderr | str trim)"
    }
  }

  let pem = $result.stdout
  if not ($pem | str starts-with "-----BEGIN") {
    error make { msg: $"KeePassXC entry ($entry) attachment ($attachment) does not contain a PEM file" }
  }
  if $label != null and not ($pem | str contains $"-----BEGIN ($label)-----") {
    error make {
      msg: $"KeePassXC entry ($entry) attachment ($attachment) does not contain a PEM ($label)"
    }
  }
  $pem
}

# Export a CA certificate to the work directory and return its private key in memory.
export def vault-ca-pair [
  credentials: record # Result of `vault-credentials`
  work: path # Directory receiving the exported certificate
  entry: string # Entry path inside the vault
  --name: string = "intermediate" # Base file name for the exported certificate
  --cert-attachment: string = "cert.pem" # Attachment holding the CA certificate
  --key-attachment: string = "key.pem" # Attachment holding the CA private key
] {
  let cert = $work | path join $"($name).crt"

  vault-pem-attachment $credentials $entry $cert_attachment $cert --label "CERTIFICATE"
  let key = vault-pem-attachment-data $credentials $entry $key_attachment

  { cert: $cert, key: $key }
}

# Copy freshly issued certificate material into a staging tree and merge it into a vault.
#
# The chain is omitted because CAs normally live in the vault as their own entries.
export def vault-import-leaves [
  credentials: record # Result of `vault-credentials`
  work: path # Work directory receiving the staging tree
  leaves: list # Records with `name`, `cert` and `key` fields
  --root-group: string = "PKI" # Root group pki2kdbx creates in the vault
  --group-map: any = null # pki2kdbx group map for exact entry paths
] {
  if ($leaves | is-empty) {
    return
  }

  let staging = $work | path join "vault-import"
  ^mkdir -p $staging
  for leaf in $leaves {
    cp $leaf.cert ($staging | path join $"($leaf.name).crt")
    cp $leaf.key ($staging | path join $"($leaf.name).key")
  }

  vault-import-pki $credentials $staging --root-group $root_group --group-map $group_map --chain none

  for leaf in $leaves {
    log info $"Added ($leaf.name) to the KeePassXC vault"
  }
}

# Merge PEM certificates and keys from a directory into a KeePassXC vault.
#
# Requires `pki2kdbx` on PATH.
# Entries are keyed by certificate fingerprint, so re-running updates entries instead of duplicating them.
export def vault-import-pki [
  credentials: record # Result of `vault-credentials`
  source: path # Directory containing PEM certificates and keys
  --root-group: string = "PKI" # Root group pki2kdbx creates in the vault
  --group-map: any # pki2kdbx group map for exact entry paths
  --chain: string = "auto" # Attach chain.pem to each entry: auto, always or none
  --dry-run # Ask pki2kdbx to report the planned merge
] {
  if not ($source | path exists) {
    error make { msg: $"Missing PEM source directory: ($source)" }
  }

  let temp_password = if ($credentials.no_password or $credentials.password_file != null) {
    null
  } else {
    let file = mktemp --suffix ".keepass-password"
    ^chmod 600 $file
    $credentials.password | save --force $file
    $file
  }

  let auth = if $credentials.no_password {
    ["--no-password"]
  } else if $credentials.password_file != null {
    ["--password-file" $credentials.password_file]
  } else {
    ["--password-file" $temp_password]
  }
  let key = if $credentials.key_file == null {
    []
  } else {
    ["--key-file" $credentials.key_file]
  }
  let group_map = if $group_map == null { [] } else { ["--group-map" $group_map] }
  let dry = if $dry_run { ["--dry-run"] } else { [] }
  let args = [
    "--src" $source
    "--db" $credentials.path
    "--root-group" $root_group
    "--chain" $chain
  ] ++ $auth ++ $key ++ $group_map ++ $dry

  try {
    let result = ^pki2kdbx ...$args | complete
    if not ($result.stdout | is-empty) {
      print --no-newline $result.stdout
    }
    if not ($result.stderr | is-empty) {
      print --no-newline --stderr $result.stderr
    }
    if $result.exit_code != 0 {
      error make { msg: $"pki2kdbx failed while updating ($credentials.path)" }
    }
  } catch {|err|
    if $temp_password != null { rm -f $temp_password }
    error make { msg: $err.msg }
  }

  if $temp_password != null { rm -f $temp_password }
}
