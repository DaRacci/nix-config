# Default Development Shell

The default `devenv` shell in this repository includes common CLI, Nix, and setup tools used across day-to-day development.

## Entering the Shell

Automatic shell entry via `direnv`, to enable this, run:

```bash
direnv allow
```

Or directly with `nix`:

```bash
nix develop --override-input devenv-root file+file://<path-to-nix-config>/.devenv/root
```

## Helper Commands

The shell also exposes repository helper commands from `flake/dev/scripts/`.
`rebuild-target` accepts `action host`, or just `host`; when the action is omitted it defaults to `switch`.
Extra args are forwarded to `nh` / `nix` after `--accept-flake-config`, and args that start with `--` must be separated with a literal `--`:

```bash
rebuild-target build nixmi -- --fallback
rebuild-target switch nixmi
```

`pki2kdbx` builds a KeePassXC vault from a directory of PEM certificates and keys.
It bundles `cryptography` for parsing and `keepassxc-cli` for writing the database:

```bash
pki2kdbx --src ./pem-tree --db pki.kdbx --native-prompt
```

When `--db` already exists, the command copies it to `<db>.bak-<timestamp>` before merging.
The staging vault uses an ephemeral key file, so only the real vault's password is requested.
Pass `--password-file` to read the vault password from a file instead of prompting.

`provision-db-guardian-certs` issues DB Guardian server certificates for guardian hosts
and a client certificate for the database primary, reading the intermediate CA from a KeePassXC vault:

```bash
provision-db-guardian-certs --vault pki.kdbx --vault-password-file vault-pass nixcloud
```

The DB Guardian helper writes `hosts/server/<host>/db-guardian-tls/{CA_CERT,SERVER_CERT,SERVER_KEY}`, adds `CLIENT_CERT`
and `CLIENT_KEY` for the primary, and encrypts every file with `sops`.
Hosts and the primary default to the values derived from the flake.
The coordinator certificate is issued by default; use `--skip-client` to omit it,
`--include-client` to state that explicitly, `--force` to rotate files that already exist, and `--dry-run` to print the plan.

Newly issued leaves are merged into the same KeePassXC vault under `leafs/<intermediate-slug>` through `pki2kdbx`,
so the vault holds every certificate it issues.
The merge backs the vault up to `<db>.bak-<timestamp>` first.
The intermediate itself is read from `intermediate/<slug>/<common name>` using its `cert.pem`
and `key.pem` attachments; override the entry, common name, or attachment names with the matching flags.

`provision-intermediate-ca` issues a service intermediate signed by the Fleet root
and stores it in a KeePassXC vault:

```bash
provision-intermediate-ca --vault pki.kdbx --vault-password-file vault-pass \
  --prefix "Backup"
```

The helper appends ` Intermediate CA` to the prefix, so this example issues `Backup Intermediate CA`.
It reads the root certificate and key from `root/Fleet mTLS Root CA`, issues a five-year intermediate
with `pathlen:0` and `keyCertSign,cRLSign`, verifies it against the root,
and merges it through `pki2kdbx` with `cert.pem` and `key.pem` attachments.
The root private key is streamed into memory for signing and is not written to the work directory.
Override the root entry, root common name, or attachment names with the matching flags.
Use `--vault-group` to choose the destination group; otherwise `pki2kdbx` derives it from the common name.
`--days`, `--path-length`, and `--key-bits` control the certificate profile, and `--dry-run` prints the plan.

## Generated `.luarc.json`

Entering the default shell refreshes `.luarc.json` in the repository root.

The shell task manages the `"workspace.library"` key by:

- creating `.luarc.json` when missing
- ensuring the current Hyprland stub path is present
- removing stale entries containing `share/hypr/stubs/`
- respect and preserve any other existing keys in `.luarc.json` that are not managed by the shell task.
