## Why

The proxy module currently hardcodes Kanidm auth into the virtual host rendering pipeline (`config.nix`), making it impossible for other extensions (e.g., crowdsec, rate-limiting, custom headers) to inject their own Caddy directives into each vhost without manually editing proxy internals. A registry-based extension system would let module authors declare self-contained extensions that compose into vhost `extraConfig`, ordered by priority — without the proxy module knowing about each extension.

## What Changes

- Add `server.proxy.extensions` option: an attribute set of extension names, each a submodule with a `priority` (int) and a `config` function that receives the vhost's full attribute set and the host config, returning a Caddy config string.
- Add `server.proxy.virtualHosts.<name>.extensions` option: a list of extension names to enable per-vhost (defaults to all registered extensions).
- Refactor `config.nix` vhost `extraConfig` generation to:
  1. Collect all enabled extensions (global registry filtered by vhost's `extensions` list).
  2. Sort by priority ascending (lower number = earlier in config).
  3. Call each extension's `config` function.
  4. Concatenate results into the vhost's Caddy block (before user `extraConfig` so users can override).
- **BREAKING**: Kanidm auth logic moves out of `config.nix` into a new proxy extension `modules/nixos/server/proxy/extensions/kanidm.nix` that registers itself. Existing `kanidm` options on vhosts remain unchanged; only the wiring moves. The `kanidm.nix` global security block is retired — its logic moves into the extension's `globalConfig` function.
- **BREAKING**: Dashboard and Cloudflared wiring in `extensions.nix` split into separate extension files (no user-facing option changes, internal restructure only).
- Add `globalConfig` function to each extension (signature: `hostConfig -> string`) for injecting directives into the top-level Caddy `globalConfig` block (sorted by priority).
- Each extension auto-manages its `enable` state via `mkDefault` based on whether its relevant configuration exists (e.g., kanidm auto-enables only when vhosts have `kanidm != null`).
- Docs updated to describe extension API and how to write new extensions.
- Add L4 extension `modules/nixos/server/proxy/extensions/l4.nix` that self-registers with priority 10 (reserved system range). Extracts the `layer4 {}` Caddy globalConfig block and firewall port openings from `config.nix` into the extension module.
- Move `l4` vhost option declaration from `options.nix` into the L4 extension's `vhostModule` (declaring `options.l4` on virtualHosts submodule).
- Remove `l4Config` generation logic from `config.nix` — L4 `globalConfig` function now handles it via `collectAllAttrsFunc`.
- Remove firewall L4 port logic from `config.nix` — L4 extension's module `config` block now handles `networking.firewall`.
- L4 extension auto-enables via `mkDefault` when any vhost has `l4 != null`.

## Capabilities

### New Capabilities

- `proxy-extension-registry`: Global registry of named extensions with priority ordering and a config generator function.
- `proxy-vhost-extension-selection`: Per-vhost opt-in/out of registered extensions via a whitelist.
- `proxy-extension-authoring`: Module authors can add files to `modules/nixos/server/proxy/extensions/` that register themselves, with no changes to proxy internals.
- `proxy-l4-extension`: Layer 4 (TCP/UDP) Caddy config migrated into a self-contained extension with its own vhost options, globalConfig generation, and firewall port management.

### Modified Capabilities

<!-- No existing proxy specs to modify -->

## Impact

- **Affected configs**: `modules/nixos/server/proxy/` (all files), `docs/src/modules/nixos/server/proxy.md`.
- **No downstream host config changes required** — vhost attribute sets are passed through unchanged.
- **New directory**: `modules/nixos/server/proxy/extensions/` for individual extension modules.
- **Non-goals**: This does NOT add new extensions beyond migrating existing kanidm/dashboard/cloudflared. It builds the framework; new extensions come later.
