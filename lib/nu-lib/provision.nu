# Shared certificate provisioning for the vault-backed helpers.

use std/log
use ./common.nu *
use ./pki.nu *
use ./sops.nu *

# Resolve the work directory a provisioning run should use.
#
# Returns `{ path, owned }`; `owned` marks a directory this call created,
# which the caller is responsible for removing with `release-work-dir`.
export def resolve-work-dir [
  path?: any # Requested work directory; null when the flag is absent
  --dry-run # Do not create the requested directory
] {
  if $path != null {
    let expanded = ($path | path expand)
    if not $dry_run {
      ^mkdir -p $expanded
    }
    { path: $expanded, owned: false }
  } else {
    { path: (^mktemp -d | str trim), owned: true }
  }
}

# Remove a work directory when `resolve-work-dir` created it.
export def release-work-dir [work: record] {
  if $work.owned {
    rm -rf $work.path
  }
}

# Resolve `--include-client` and `--skip-client` against a command default.
export def client-enabled [
  --include-client
  --skip-client
  --default-include
] {
  if $include_client and $skip_client {
    fail "Cannot combine --include-client with --skip-client"
  }
  if $include_client {
    true
  } else if $skip_client {
    false
  } else {
    $default_include
  }
}

# Issue a leaf, write its CA/certificate/key into a service directory, and encrypt them.
#
# Returns `{ name, cert, key }` for `vault-import-leaves`,
# or null when the target files already exist and `--force` is not set.
export def provision-leaf [
  output: path # Repository root
  work: path # Work directory for the key, CSR and extension files
  host: string # Host receiving the files
  service: string # Service directory under the host
  kind: string # server or client
  ca_cert: path # Certificate written to CA_CERT
  ca_key?: any # Issuing CA private key path
  --ca-key-data: any = null # Issuing CA private key PEM passed on standard input
  --issuer-cert: any = null # Certificate that issues the leaf; defaults to ca_cert
  --name: string # Leaf file base name
  --common-name: string # Subject common name
  --san: list<string> = [] # Subject alternative names
  --key-usage: string = "critical,digitalSignature" # keyUsage extension value
  --extended-key-usage: string = "clientAuth" # extendedKeyUsage extension value
  --serial-name: string # CA serial file base name
  --label: any = null # Log description
  --force # Overwrite existing certificate files
] {
  let target = leaf-files $output $host $service $kind
  let label = if $label == null { $"($kind) certificate for ($host)" } else { $label }

  if (not $force) and ($target.files | any {|file| $file | path exists }) {
    log warning $"Skipping ($label): files already exist; use --force to rotate"
    return null
  }

  let issuer = if $issuer_cert == null { $ca_cert } else { $issuer_cert }

  let material = (
    issue-leaf --work-dir $work --name $name --common-name $common_name
      --san $san
      --key-usage $key_usage
      --extended-key-usage $extended_key_usage
      --ca-cert $issuer --ca-key $ca_key --ca-key-data $ca_key_data
      --serial ($work | path join $"($serial_name).srl")
      --verify
  )

  ^mkdir -p $target.dir
  cp $ca_cert $target.ca
  cp $material.chain $target.cert
  cp $material.key $target.key
  encrypt-binary $target.ca
  encrypt-binary $target.cert
  encrypt-binary $target.key

  log info $"Provisioned ($label)"

  { name: $common_name, cert: $material.cert, key: $material.key }
}

# Paths `provision-leaf` writes for a leaf kind.
def leaf-files [
  output: path
  host: string
  service: string
  kind: string
] {
  let dir = service-cert-dir $output $host $service
  let prefix = if $kind == "server" {
    "SERVER"
  } else if $kind == "client" {
    "CLIENT"
  } else {
    fail $"Unknown leaf kind: ($kind)"
  }

  let files = {
    dir: $dir
    ca: ($dir | path join "CA_CERT")
    cert: ($dir | path join $"($prefix)_CERT")
    key: ($dir | path join $"($prefix)_KEY")
  }

  $files | insert files [$files.ca $files.cert $files.key]
}
