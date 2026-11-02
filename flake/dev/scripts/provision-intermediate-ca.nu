#!/usr/bin/env nu

use std/log
use lib/common.nu *
use lib/keepass.nu *
use lib/pki.nu *
use lib/provision.nu *

const VAULT_ROOT_GROUP = "PKI"
const VAULT_ROOT_ENTRY = "root/Fleet mTLS Root CA"
const VAULT_ROOT_COMMON_NAME = "Fleet mTLS Root CA"
const VAULT_CERT_ATTACHMENT = "cert.pem"
const VAULT_KEY_ATTACHMENT = "key.pem"

# Issue a service intermediate CA and store it in a KeePassXC vault.
#
# The root certificate and private key are read from the vault.
# The new intermediate is validated against the root and merged back through `pki2kdbx`.
def main [
  --vault: path # KeePassXC database holding the root and receiving the intermediate
  --vault-password-file: path # Vault password file; prompts when omitted
  --vault-key-file: path # KeePassXC key file for the vault
  --vault-no-password # Unlock the vault with a key file only
  --vault-root-group: string = $VAULT_ROOT_GROUP # Root group pki2kdbx merges entries into
  --prefix: string # Common name prefix to go before " Intermediate CA".
  --vault-group: string # Vault group receiving the entry; pki2kdbx derives it when omitted
  --root-entry: string = $VAULT_ROOT_ENTRY # Vault entry holding the root certificate and key
  --root-common-name: string = $VAULT_ROOT_COMMON_NAME # Expected common name of the root
  --cert-attachment: string = $VAULT_CERT_ATTACHMENT # Vault attachment holding the root certificate
  --key-attachment: string = $VAULT_KEY_ATTACHMENT # Vault attachment holding the root private key
  --days: int = 1825 # Intermediate lifetime
  --path-length: int = 0 # Maximum CA depth below the intermediate
  --key-bits: int = 4096 # RSA key size for the intermediate
  --work-dir: path # Temporary key/CSR directory; a temporary directory is used by default
  --dry-run # Print planned work without writing or merging anything
] {
  let work = resolve-work-dir $work_dir --dry-run=$dry_run

  if $dry_run {
    log info $"Would use work directory ($work.path)"
  }

  try {
    if $vault == null {
      fail "--vault is required"
    }
    if $prefix == null or (($prefix | str trim) | is-empty) {
      fail "--prefix is required"
    }

    let prefix = $prefix | str trim
    let lowered = $prefix | str lowercase
    if $lowered == "intermediate ca" or ($lowered | str ends-with " intermediate ca") {
      fail "--prefix must omit the `Intermediate CA` suffix"
    }
    let common_name = $"($prefix) Intermediate CA"

    let credentials = vault-credentials $vault --password-file $vault_password_file --key-file $vault_key_file --no-password=$vault_no_password
    let destination = if $vault_group == null { "the pki2kdbx intermediate group" } else { $vault_group }

    if $dry_run {
      log info $"Would issue ($common_name) from ($root_common_name) and store it in ($destination)"
    } else {
      let root = vault-ca-pair $credentials $work.path $root_entry --name "root" --cert-attachment $cert_attachment --key-attachment $key_attachment
      validate-ca-cert $root.cert --common-name $root_common_name --self-signed
      validate-key-pair $root.cert --key-data $root.key

      let material = (
        issue-ca --work-dir $work.path --name "intermediate"
          --common-name $common_name
          --ca-cert $root.cert --ca-key-data $root.key
          --serial ($work.path | path join "root.srl")
          --days $days --path-length $path_length --key-bits $key_bits
      )
      validate-ca-cert $material.cert --common-name $common_name
      validate-key-pair $material.cert $material.key
      verify-leaf $material.cert $root.cert

      let group_map = if $vault_group == null {
        null
      } else {
        let file = $work.path | path join "group-map.tsv"
        $"($common_name)\t($vault_group)" | save --force $file
        $file
      }

      vault-import-leaves $credentials $work.path [
        { name: "intermediate", cert: $material.cert, key: $material.key }
      ] --root-group $vault_root_group --group-map $group_map
      log info $"Stored ($common_name) in the KeePassXC vault"
    }
  } catch {|err|
    release-work-dir $work
    fail $"Intermediate CA provisioning failed: ($err.msg)"
  }

  release-work-dir $work
}
