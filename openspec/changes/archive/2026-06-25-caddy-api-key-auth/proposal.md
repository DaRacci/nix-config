## Why

Several internal services behind the Caddy proxy need simple API key authentication without the full overhead of OAuth2 (identity providers, portals, group policies). Following the proxy module's extension registry architecture, a new `api-key-auth` extension will auto-generate sops secrets and wire up caddy-security's `authorize` directive with a static API key matcher.

## What Changes

- New extension file: `modules/nixos/server/proxy/extensions/api-key-auth.nix` — self-registers `server.proxy.extensions.api-key-auth`
- Per-vhost option `requireApiKey` (submodule with `enable` + `bypassPaths`) declared via `options.server.proxy.virtualHosts.<name>` — NixOS module system merges it natively
- Extension auto-enables via `mkDefault` when any vhost has `requireApiKey.enable = true` (same pattern as kanidm/l4/cloudflared)
- Extension `config` function generates per-vhost Caddy config: bypass matcher for `bypassPaths`, `route /auth/apikey/*` for authorize flow, `authorize with` in handle
- Extension `globalConfig` function generates `order authorize before reverse_proxy` + per-vhost caddy-security `authorize` blocks referencing named Caddy matchers (`@<name>_apikey_key`) defined in the per-vhost `config` function via `header Req-API-Key {env.API_KEY_<VHOST>}`
- Extension sets `consumesExtraConfig = true` — embeds `_resolvedExtraConfig` in output; existing assertion in `config.nix` prevents coexistence with `kanidm` extension on same vhost
- Auto-generated sops secret per vhost at `PROXY_AUTH/<VHOST_NAME>_API_KEY` (derived from vhost name)
- Secret injected into caddy via `{env.API_KEY_<VHOST>}` placeholders, loaded via systemd `LoadCredential`
- Named Caddy matcher `@<name>_apikey_key` per vhost validates `Req-API-Key` header against the env var; this matcher is referenced from the caddy-security `authorize` block via `with @<name>_apikey_key`
- Import line added to `default.nix`: `(importModule ./extensions/api-key-auth.nix { inherit proxyLib; })`

## Capabilities

### New Capabilities

- `caddy-api-key-auth`: Per-virtual-host API key authentication using caddy-security's authorize directive, implemented as a self-registering proxy extension, with auto-generated sops secrets and optional path bypass.

### Modified Capabilities

<!-- None -->

## Impact

- **New file**: `modules/nixos/server/proxy/extensions/api-key-auth.nix` — extension self-registration, vhost option declarations, config/globalConfig functions, sops secrets
- **Modified**: `modules/nixos/server/proxy/default.nix` — add one import line for the new extension
- **No changes** to `config.nix`, `options.nix`, or any existing extension files
- **Non-goals**: No Kanidm provisioning changes, no rotation/revocation mechanism, no rate limiting, no multi-key support
