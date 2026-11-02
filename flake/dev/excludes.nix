# Paths that both treefmt and rumdl skip.
# `flake/dev/devenv.nix` converts these globs into the anchored regexes prek
# expects, so the formatter, the linter and the git hooks agree on one list.
[
  ".opencode/**"
  "openspec/**"
  "**/secrets.yaml"
  "**/ssh_host_ed25519_key.pub"
  "hosts/server/nixcloud/provisioning.json"
  "hosts/server/nixio/redis-mappings.json"
  "hosts/server/nixio/tunnel/credentials.json"
]
