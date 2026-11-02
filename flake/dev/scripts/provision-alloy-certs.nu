#!/usr/bin/env nu

use std/log
use lib/common.nu *
use lib/flake.nu *
use lib/keepass.nu *
use lib/pki.nu *
use lib/provision.nu *
use lib/sops.nu *

const CLIENT_COMMON_NAME = "alloy-capture-relay"
const VAULT_ROOT_GROUP = "PKI"

# The pki2kdbx layout stores CAs under groups derived from their common names.
const VAULT_ROOT_ENTRY = "root/Fleet mTLS Root CA"
const VAULT_ROOT_COMMON_NAME = "Fleet mTLS Root CA"
const VAULT_INTERMEDIATE_ENTRY = "intermediate/alloy-dynamic-capture/Alloy Dynamic Capture Intermediate CA"
const VAULT_INTERMEDIATE_COMMON_NAME = "Alloy Dynamic Capture Intermediate CA"
const VAULT_CERT_ATTACHMENT = "cert.pem"
const VAULT_KEY_ATTACHMENT = "key.pem"

# Issue per-host Alloy dynamic capture server certificates and encrypt them.
#
# The root certificate and intermediate certificate/key are read from a KeePassXC vault.
# Newly issued leaves are merged back into the same vault through pki2kdbx.
def main [
  --vault: path # KeePassXC database holding the CA and receiving the issued leaves
  --vault-password-file: path # Vault password file; prompts when omitted
  --vault-key-file: path # KeePassXC key file for the vault
  --vault-no-password # Unlock the vault with a key file only
  --vault-root-group: string = $VAULT_ROOT_GROUP # Root group pki2kdbx merges entries into
  --root-entry: string = $VAULT_ROOT_ENTRY # Vault entry holding the Fleet root certificate
  --root-common-name: string = $VAULT_ROOT_COMMON_NAME # Expected common name of the Fleet root
  --intermediate-entry: string = $VAULT_INTERMEDIATE_ENTRY # Vault entry holding the Alloy intermediate
  --intermediate-common-name: string = $VAULT_INTERMEDIATE_COMMON_NAME # Expected common name of the intermediate
  --cert-attachment: string = $VAULT_CERT_ATTACHMENT # Vault attachment holding CA certificates
  --key-attachment: string = $VAULT_KEY_ATTACHMENT # Vault attachment holding the intermediate private key
  --domain: string # Fleet proxy domain; derived from the IO primary when omitted
  --output-dir: path # Repository root; defaults to GIT_ROOT
  --work-dir: path # Temporary key/CSR directory; a temporary directory is used by default
  --client-host: string = "nixmon" # Host that receives the relay client certificate
  --force # Overwrite existing Alloy certificate files
  --include-client # Also issue the relay client certificate and key
  --skip-client # Do not issue the relay client certificate and key
  --dry-run # Print planned work without writing or encrypting files
  ...hosts: string # Hosts to provision; defaults to every server host
] {
  let include_client = client-enabled --include-client=$include_client --skip-client=$skip_client
  let work = resolve-work-dir $work_dir --dry-run=$dry_run
  let output = if $output_dir == null { $env.GIT_ROOT } else { $output_dir | path expand }

  if $dry_run {
    log info $"Would use work directory ($work.path)"
  }

  try {
    if $vault == null {
      fail "--vault is required"
    }

    let credentials = vault-credentials $vault --password-file $vault_password_file --key-file $vault_key_file --no-password=$vault_no_password

    let all_hosts = list-server-hosts
    let selected_hosts = if ($hosts | is-empty) { $all_hosts } else { $hosts }
    let domain = if $domain == null { proxy-domain } else { $domain }

    for host in $selected_hosts {
      if not ($host in $all_hosts) {
        fail $"Unknown server host: ($host)"
      }
    }
    if $include_client and not ($client_host in $all_hosts) {
      fail $"Unknown client host: ($client_host)"
    }

    if $dry_run {
      for host in $selected_hosts {
        let target = service-cert-dir $output $host "alloy"
        log info $"Would issue server certificate for ($host) in ($target) and merge it into the vault"
      }
      if $include_client {
        let target = service-cert-dir $output $client_host "alloy"
        log info $"Would issue relay client certificate in ($target) and merge it into the vault"
      }
    } else {
      let ca = read-ca $credentials $work.path $root_entry $root_common_name $intermediate_entry $intermediate_common_name $cert_attachment $key_attachment

      let server_leaves = $selected_hosts | each {|host|
        (
          provision-leaf $output $work.path $host "alloy" "server" $ca.root --ca-key-data $ca.key
            --issuer-cert $ca.cert
            --name $host --common-name $host
            --san [ $"DNS:($host)" $"DNS:($host).localdomain" $"DNS:($host).($domain)" "IP:127.0.0.1" ]
            --key-usage "critical,digitalSignature,keyEncipherment"
            --extended-key-usage "serverAuth"
            --serial-name "alloy-intermediate"
            --label $"Alloy server certificate for ($host)"
            --force=$force
        )
      } | compact

      let client_leaves = if $include_client {
        [ (
          provision-leaf $output $work.path $client_host "alloy" "client" $ca.root --ca-key-data $ca.key
            --issuer-cert $ca.cert
            --name "alloy-client" --common-name $CLIENT_COMMON_NAME
            --san [ $"DNS:($CLIENT_COMMON_NAME)" ]
            --key-usage "critical,digitalSignature"
            --extended-key-usage "clientAuth"
            --serial-name "alloy-intermediate"
            --label $"Alloy relay client certificate on ($client_host)"
            --force=$force
        ) ] | compact
      } else {
        []
      }

      vault-import-leaves $credentials $work.path ($server_leaves ++ $client_leaves) --root-group $vault_root_group
    }
  } catch {|err|
    release-work-dir $work
    fail $"Alloy certificate provisioning failed: ($err.msg)"
  }

  release-work-dir $work
}

def proxy-domain [] {
  try {
    flake-eval r#'
      let
        cfgs = flake.nixosConfigurations;
        servers = builtins.filter (
          name: cfgs.${name}.config.host.device.role == "server"
        ) (builtins.attrNames cfgs);
        io = builtins.head (
          builtins.filter (name: cfgs.${name}.config.server.ioPrimaryHost == name) servers
        );
      in cfgs.${io}.config.server.proxy.domain
    '# --raw | str trim
  } catch {|err|
    fail $"Could not derive the proxy domain; pass --domain explicitly: ($err.msg)"
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
  let root = $work | path join "alloy-root.crt"
  vault-pem-attachment $credentials $root_entry $cert_attachment $root --label "CERTIFICATE"
  validate-ca-cert $root --common-name $root_common_name --self-signed

  let intermediate = vault-ca-pair $credentials $work $intermediate_entry --name "alloy-intermediate" --cert-attachment $cert_attachment --key-attachment $key_attachment
  validate-ca-cert $intermediate.cert --common-name $intermediate_common_name
  validate-key-pair $intermediate.cert --key-data $intermediate.key
  verify-leaf $intermediate.cert $root

  { root: $root, cert: $intermediate.cert, key: $intermediate.key }
}
