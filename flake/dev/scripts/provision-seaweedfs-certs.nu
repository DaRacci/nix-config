#!/usr/bin/env nu

use std/log
use lib/common.nu *
use lib/flake.nu *
use lib/keepass.nu *
use lib/pki.nu *
use lib/provision.nu *
use lib/sops.nu *

const VAULT_ROOT_GROUP = "PKI"
const VAULT_ROOT_ENTRY = "root/Fleet mTLS Root CA"
const VAULT_ROOT_COMMON_NAME = "Fleet mTLS Root CA"
const VAULT_INTERMEDIATE_ENTRY = "intermediate/seaweedfs/SeaweedFS Intermediate CA"
const VAULT_INTERMEDIATE_COMMON_NAME = "SeaweedFS Intermediate CA"
const VAULT_CERT_ATTACHMENT = "cert.pem"
const VAULT_KEY_ATTACHMENT = "key.pem"
const TLS_PATH = "hosts/server/nixio/seaweedfs-tls"
const SERIAL_NAME = "seaweedfs-intermediate"

# Component names double as gRPC common names, so they match `allowed_commonNames` in security.toml.
const SERVICES = [
  master
  volume
  filer
  admin
  client
  worker
]

# Issue SeaweedFS component certificates and encrypt them.
#
# The root certificate and the SeaweedFS intermediate certificate/key are read from a KeePassXC vault.
# `CA` is written as the root plus intermediate bundle, and each `<SERVICE>_CRT` as leaf first, then intermediate.
def main [
  --vault: path # KeePassXC database holding the CA material
  --vault-password-file: path # Vault password file; prompts when omitted
  --vault-key-file: path # KeePassXC key file for the vault
  --vault-no-password # Unlock the vault with a key file only
  --vault-root-group: string = $VAULT_ROOT_GROUP # Root group pki2kdbx merges entries into
  --root-entry: string = $VAULT_ROOT_ENTRY # Vault entry holding the Fleet root certificate
  --root-common-name: string = $VAULT_ROOT_COMMON_NAME # Expected common name of the Fleet root
  --intermediate-entry: string = $VAULT_INTERMEDIATE_ENTRY # Vault entry holding the SeaweedFS intermediate
  --intermediate-common-name: string = $VAULT_INTERMEDIATE_COMMON_NAME # Expected common name of the intermediate
  --cert-attachment: string = $VAULT_CERT_ATTACHMENT # Vault attachment holding CA certificates
  --key-attachment: string = $VAULT_KEY_ATTACHMENT # Vault attachment holding the intermediate private key
  --domain: string # Fleet proxy domain; derived from the IO primary when omitted
  --output-dir: path # Repository root; defaults to GIT_ROOT
  --work-dir: path # Temporary key/CSR directory; a temporary directory is used by default
  --days: int = 730 # Certificate lifetime
  --force # Reissue the selected leaves even when their files already exist
  --force-ca # Rewrite the CA bundle even when it already exists
  --dry-run # Print planned work without writing or encrypting files
  ...services: string # Components to provision; defaults to every component
] {
  let work = resolve-work-dir $work_dir --dry-run=$dry_run
  let output = if $output_dir == null { $env.GIT_ROOT } else { $output_dir | path expand }
  let domain = if $domain == null { proxy-domain } else { $domain }
  let selected = if ($services | is-empty) { $SERVICES } else { $services }
  let target = $output | path join $TLS_PATH
  let serial = $work.path | path join $"($SERIAL_NAME).srl"
  let sans = service-sans $domain

  for service in $selected {
    if not ($service in $SERVICES) {
      fail $"Unknown SeaweedFS component: ($service). Expected one of ($SERVICES | str join ', ')."
    }
  }

  if $dry_run {
    log info $"Would use work directory ($work.path)"
    for service in $selected {
      log info $"Would issue ($service) with SANs ($sans | get $service | str join ', ')"
      log info $"Would write ($target | path join $"($service | str uppercase)_CRT") and its key"
    }
    log info $"Would write the CA bundle to ($target | path join 'CA')"
    return
  }

  try {
    if $vault == null {
      fail "--vault is required"
    }

    let credentials = vault-credentials $vault --password-file $vault_password_file --key-file $vault_key_file --no-password=$vault_no_password
    let ca = read-ca $credentials $work.path $root_entry $root_common_name $intermediate_entry $intermediate_common_name $cert_attachment $key_attachment

    ^mkdir -p $target

    write-ca-bundle $target $ca $force_ca

    for service in $selected {
      issue-service-leaf $target $work.path $serial $service ($sans | get $service) $ca $days $force
    }
  } catch {|err|
    release-work-dir $work
    fail $"SeaweedFS certificate provisioning failed: ($err.msg)"
  }

  release-work-dir $work
}

def proxy-domain [] {
  try {
    flake-eval r#'flake.data.site.domain'# --raw | str trim
  } catch {|err|
    fail $"Could not derive the proxy domain; pass --domain explicitly: ($err.msg)"
  }
}

# Server names each component answers to, matching the proxy virtual hosts.
#
# The master keeps the pre-rename hostname because clients still dial `seaweedfs.<domain>`.
def service-sans [domain: string] {
  let local = [
    "DNS:localhost"
    "IP:127.0.0.1"
  ]
  {
    master: ([
      $"DNS:seaweedfs.($domain)"
      $"DNS:master.seaweedfs.($domain)"
    ] ++ $local)
    volume: ([ $"DNS:volume.seaweedfs.($domain)" ] ++ $local)
    filer: ([ $"DNS:filer.seaweedfs.($domain)" ] ++ $local)
    admin: ([ $"DNS:admin.seaweedfs.($domain)" ] ++ $local)
    client: ([ "DNS:client" ] ++ $local)
    worker: ([ "DNS:worker" ] ++ $local)
  }
}

# Export and validate the root and intermediate CA material from the vault.
def read-ca [
  credentials: record
  work: path
  root_entry: string
  root_common_name: string
  intermediate_entry: string
  intermediate_common_name: string
  cert_attachment: string
  key_attachment: string
] {
  let root = $work | path join "seaweedfs-root.crt"
  vault-pem-attachment $credentials $root_entry $cert_attachment $root --label "CERTIFICATE"
  validate-ca-cert $root --common-name $root_common_name --self-signed

  let intermediate = vault-ca-pair $credentials $work $intermediate_entry --name "seaweedfs-intermediate" --cert-attachment $cert_attachment --key-attachment $key_attachment
  validate-ca-cert $intermediate.cert --common-name $intermediate_common_name
  validate-key-pair $intermediate.cert --key-data $intermediate.key
  verify-leaf $intermediate.cert $root

  { root: $root, cert: $intermediate.cert, key: $intermediate.key }
}

# Write the trust bundle consumers receive, which is the root plus the intermediate.
def write-ca-bundle [target: path, ca: record, force: bool] {
  let bundle = $target | path join "CA"
  if (not $force) and ($bundle | path exists) {
    log warning "Skipping CA bundle: it already exists; use --force-ca to rewrite"
    return
  }

  ^cat $ca.root $ca.cert | save --force $bundle
  encrypt-binary $bundle
  log info $"Provisioned CA bundle in ($target)"
}

# Issue one component leaf, write its chain and key, and encrypt them.
def issue-service-leaf [
  target: path
  work: path
  serial: path
  service: string
  san: list<string>
  ca: record
  days: int
  force: bool
] {
  let upper = $service | str uppercase
  let crt = $target | path join $"($upper)_CRT"
  let key = $target | path join $"($upper)_KEY"

  if (not $force) and (($crt | path exists) or ($key | path exists)) {
    log warning $"Skipping ($service): files already exist; use --force to rotate"
    return
  }

  let material = (
    issue-leaf --work-dir $work --name $service --common-name $service
      --san $san
      --key-usage "critical,digitalSignature,keyEncipherment"
      --extended-key-usage "serverAuth,clientAuth"
      --ca-cert $ca.cert --ca-key-data $ca.key
      --serial $serial
      --days $days
      --verify
  )

  cp $material.chain $crt
  cp $material.key $key
  encrypt-binary $crt
  encrypt-binary $key
  log info $"Provisioned ($service) certificate in ($target)"
}
