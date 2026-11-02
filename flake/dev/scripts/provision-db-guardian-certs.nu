#!/usr/bin/env nu

use std/log
use lib/common.nu *
use lib/flake.nu *
use lib/keepass.nu *
use lib/pki.nu *
use lib/provision.nu *
use lib/sops.nu *

const CLIENT_COMMON_NAME = "db-guardian-coordinator"

# The pki2kdbx layout stores each certificate under a group derived from its common name, with the certificate and key as PEM attachments.
const VAULT_INTERMEDIATE_ENTRY = "intermediate/db-guardian/DB Guardian Intermediate CA"
const VAULT_INTERMEDIATE_COMMON_NAME = "DB Guardian Intermediate CA"
const VAULT_CERT_ATTACHMENT = "cert.pem"
const VAULT_KEY_ATTACHMENT = "key.pem"
const VAULT_ROOT_GROUP = "PKI"

# Issue DB Guardian server and coordinator leaves from the offline intermediate.
#
# The DB Guardian intermediate certificate and key are read from a KeePassXC vault.
# Newly issued leaves are merged back into the same vault through `pki2kdbx`.
def main [
  --vault: path # KeePassXC database holding the DB Guardian intermediate
  --vault-password-file: path # Vault password file; prompts when omitted
  --vault-key-file: path # KeePassXC key file for the vault
  --vault-no-password # Unlock the vault with a key file only
  --vault-root-group: string = $VAULT_ROOT_GROUP # Root group pki2kdbx merges entries into
  --intermediate-entry: string = $VAULT_INTERMEDIATE_ENTRY # Vault entry path for the intermediate
  --intermediate-common-name: string = $VAULT_INTERMEDIATE_COMMON_NAME # Expected common name of the intermediate
  --cert-attachment: string = $VAULT_CERT_ATTACHMENT # Vault attachment holding the intermediate certificate
  --key-attachment: string = $VAULT_KEY_ATTACHMENT # Vault attachment holding the intermediate private key
  --primary-host: string # Database primary; derived from the flake when omitted
  --output-dir: path # Repository root; defaults to GIT_ROOT
  --work-dir: path # Temporary key/CSR directory; a temporary directory is used by default
  --force # Overwrite existing DB Guardian certificate files
  --include-client # Issue the coordinator client certificate
  --skip-client # Do not issue the coordinator client certificate
  --dry-run # Print planned work without writing or encrypting files
  ...hosts: string # Guardian hosts to provision; defaults to every guardian host
] {
  let include_client = client-enabled --include-client=$include_client --skip-client=$skip_client --default-include
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

    let topology = cluster-topology
    let primary = if $primary_host == null { $topology.primary } else { $primary_host }
    if $primary not-in $topology.servers {
      fail $"Unknown database primary: ($primary)"
    }

    let guardian_hosts = if ($hosts | is-empty) { $topology.guardians } else { $hosts }
    for host in $guardian_hosts {
      if $host == $primary {
        fail $"($host) is the database primary; it receives the client certificate, not a server certificate"
      }
      if $host not-in $topology.guardians {
        fail $"($host) is not a database guardian host"
      }
    }

    if $dry_run {
      for host in $guardian_hosts {
        log info $"Would issue server certificate for ($host) and merge it into the vault"
      }
      if $include_client {
        log info $"Would issue coordinator client certificate for ($primary) and merge it into the vault"
      }
    } else {
      let material = vault-ca-pair $credentials $work.path $intermediate_entry --name "db-guardian-intermediate" --cert-attachment $cert_attachment --key-attachment $key_attachment
      validate-ca-cert $material.cert --common-name $intermediate_common_name
      validate-key-pair $material.cert --key-data $material.key

      let server_leaves = $guardian_hosts | each {|host|
        (
          provision-leaf $output $work.path $host "db-guardian-tls" "server" $material.cert --ca-key-data $material.key
            --name $host --common-name $host
            --san [ $"DNS:($host)" $"DNS:($host).localdomain" ]
            --key-usage "critical,digitalSignature,keyEncipherment"
            --extended-key-usage "serverAuth"
            --serial-name "db-guardian-intermediate"
            --label $"DB Guardian server certificate for ($host)"
            --force=$force
        )
      } | compact

      let client_leaves = if $include_client {
        [ (
          provision-leaf $output $work.path $primary "db-guardian-tls" "client" $material.cert --ca-key-data $material.key
            --name "db-guardian-client" --common-name $CLIENT_COMMON_NAME
            --san [ $"DNS:($CLIENT_COMMON_NAME)" ]
            --key-usage "critical,digitalSignature"
            --extended-key-usage "clientAuth"
            --serial-name "db-guardian-intermediate"
            --label $"DB Guardian coordinator client certificate on ($primary)"
            --force=$force
        ) ] | compact
      } else {
        []
      }

      vault-import-leaves $credentials $work.path ($server_leaves ++ $client_leaves) --root-group $vault_root_group
    }
  } catch {|err|
    release-work-dir $work
    fail $"DB Guardian certificate provisioning failed: ($err.msg)"
  }

  release-work-dir $work
}

# Return the database primary and the guardian set the module derives.
def cluster-topology [] {
  try {
    flake-eval r#'
      let
        cfgs = flake.nixosConfigurations;
        servers = builtins.filter (
          name: cfgs.${name}.config.host.device.role == "server"
        ) (builtins.attrNames cfgs);
        primary = cfgs.${builtins.head servers}.config.server.ioPrimaryHost;
        hasDatabases = name:
          (builtins.attrNames cfgs.${name}.config.server.database.postgres) != [ ]
          || (builtins.attrNames cfgs.${name}.config.server.database.redis) != [ ];
        guardians = builtins.filter (
          name: name != primary && hasDatabases name
        ) servers;
      in {
        inherit primary guardians servers;
      }
    '# --json | from json
  } catch {|err|
    fail $"Could not derive the database topology; pass --primary-host and hosts explicitly: ($err.msg)"
  }
}
