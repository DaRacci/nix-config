## Why

Several internal services behind the Caddy proxy need simple API key authentication without the full overhead of OAuth2 (identity providers, portals, group policies). A `requireApiKey` option on virtual hosts will auto-generate sops secrets and wire up caddy-security's `authorize` directive with a static API key matcher — following the same opt-in-per-vhost extension approach used by the proxy module's existing auth extensions.

## What Changes

- New `requireApiKey` option on `server.proxy.virtualHosts.<name>`, a submodule with `enable` bool and `bypassPaths`
- New `api-key-auth.nix` module that generates caddy-security `authorize` blocks per vhost using the `http.request.header.Req-API-Key` header matcher
- Auto-generated sops secret per vhost at `PROXY_AUTH/<VHOST_NAME>_API_KEY` (derived from vhost name)
- The secret file path is injected into caddy via `{env.API_KEY_<VHOST>}` placeholders
- Opt-in `bypassPaths` to skip auth for specific paths — a named caddy matcher routes matching requests past the authorize block

## Capabilities

### New Capabilities

- `caddy-api-key-auth`: Per-virtual-host API key authentication using caddy-security's authorize directive, with auto-generated sops secrets and optional path bypass.

### Modified Capabilities

<!-- None -->

## Impact

- **New file**: `modules/nixos/server/proxy/api-key-auth.nix` — caddy global config generation (authorize blocks, order directives)
- **Modified**: `modules/nixos/server/proxy/options.nix` — new `requireApiKey` option on virtualHosts
- **Modified**: `modules/nixos/server/proxy/config.nix` — wire `requireApiKey` into vhost extraConfig: a named matcher for bypass paths, a `route /auth/apikey/*` for the authorize flow, and `authorize with` in the default handle
- **Modified**: `modules/nixos/server/proxy/default.nix` — import new module, thread `proxyLib` helpers
- **Non-goals**: No Kanidm provisioning changes, no rotation/revocation mechanism, no rate limiting, no multi-key support
