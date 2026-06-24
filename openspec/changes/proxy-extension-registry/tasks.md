## 1. Extension Registry Foundation

- [x] 1.1 Add `server.proxy.extensions` option in `options.nix` (attrsOf submodule with priority, enable, consumesExtraConfig, config, globalConfig)
- [x] 1.2 Add `_name` read-only option to the vhost submodule in `options.nix`
- [x] 1.3 Add `server.proxy.virtualHosts.<name>.extensions` option in `options.nix` (nullOr listOf str, default null)
- [x] 1.4 Create `modules/nixos/server/proxy/extensions/` directory
- [x] 1.5 Add `getExtensionsForVhost` function to `proxyLib` in `default.nix`: filters by vhost whitelist, filters by enable, sorts by priority (ascending, alphabetical tie-break), returns sorted list
- [x] 1.6 Add `getGlobalConfigFromExtensions` function to `proxyLib`: collects `globalConfig` from all enabled extensions, sorted by priority, concatenated
- [x] 1.7 Add assertion: vhost whitelist names must exist in the registry (error if nonexistent extension name referenced)
- [x] 1.8 Add assertion: at most one extension with `consumesExtraConfig = true` per vhost
- [x] 1.9 Add assertion: vhost with `kanidm != null` and `extensions = []` raises a warning

## 2. Migrate Kanidm to Extension (vhost options + config + globalConfig)

- [x] 2.1 Move `kanidm` option declaration from `options.nix` vhost submodule into `options` block of `extensions/kanidm.nix` (full path: `options.server.proxy.virtualHosts.<name>.kanidm`)
- [x] 2.2 Move `kanidmContexts` option declaration from `options.nix` into `extensions/kanidm.nix`'s `options` block (full path: `options.server.proxy.kanidmContexts`)
- [x] 2.3 Create `modules/nixos/server/proxy/extensions/kanidm.nix` that registers `server.proxy.extensions.kanidm` with: priority 50, consumesExtraConfig=true, `enable = mkDefault proxyLib.hasAnyKanidm`, config function returning auth directives or "", globalConfig function returning the `security { ... }` block (identity providers, portals, policies)
- [x] 2.4 The kanidm extension's config function (name -> vh -> hostCfg) uses `resolveKanidmContext` from proxyLib, returns `""` when `vh.kanidm == null`
- [x] 2.5 When `vh.kanidm != null`: config function generates bypass handle + auth handle structure, wrapping `vh._resolvedExtraConfig` inside both handles, using `vh._name` for portal/policy references
- [x] 2.6 Move the security block generation logic from `kanidm.nix` into the kanidm extension's `globalConfig` function
- [x] 2.7 Import kanidm extension in `proxy/default.nix` via `importModule`, remove old `kanidm.nix` import
- [x] 2.8 Delete `modules/nixos/server/proxy/kanidm.nix` (all logic moved to extension)
- [x] 2.9 Rewrite `config.nix` vhost `extraConfig` generation: resolve `_resolvedExtraConfig` on each vhost, call `getExtensionsForVhost`, iterate extensions calling their config functions, check `consumesExtraConfig` to decide whether to append raw `extraConfig`
- [x] 2.10 Rewrite `config.nix` globalConfig generation: call `getGlobalConfigFromExtensions`, concatenate into `services.caddy.globalConfig`
- [x] 2.11 Remove the old `optionalString (vh.kanidm != null)` block in `config.nix` (replaced by extension)

## 3. Migrate Dashboard to Extension

- [x] 3.1 Create `modules/nixos/server/proxy/extensions/dashboard.nix` that: registers `server.proxy.extensions.dashboard` with priority 200, sets `enable = mkDefault (cfg.virtualHosts != {})`, config function returns `""`, globalConfig returns `""`
- [x] 3.2 Move `server.dashboard.items` generation from `extensions.nix` to dashboard extension's module config block
- [x] 3.3 Import dashboard extension in `proxy/default.nix`

## 4. Migrate Cloudflared to Extension

- [x] 4.1 Cloudflared extension created: registers `server.proxy.extensions.cloudflared` with priority 200, auto-enable via getAllAttrsFunc, config function returns `"import public"` when vh.public, globalConfig returns `""`
- [x] 4.2 `public` option declared in cloudflared extension's `options` block, removed from `options.nix`
- [x] 4.3 Move `services.cloudflared.tunnels` ingress generation from `extensions.nix` to cloudflared extension's module config block
- [x] 4.4 Remove `import public` line from `config.nix` vhost extraConfig generation (now handled by cloudflared extension's config function)
- [x] 4.5 Import cloudflared extension in `proxy/default.nix`

## 5. Clean up Original extensions.nix

- [x] 5.1 Rename `modules/nixos/server/proxy/extensions.nix` to `modules/nixos/server/proxy/kanidm-provisioning.nix` (retains only Kanidm provisioning: sops secrets + oauth2 systems)
- [x] 5.2 Update import in `proxy/default.nix` from `./extensions.nix` to `./kanidm-provisioning.nix`

## 6. Validate and Document

- [x] 6.1 Run `nix fmt .` on all changed files
- [x] 6.2 Build nixio configuration to verify no regressions (pre-existing unrelated error: ai-agent.nix:42 missing webhook)
- [x] 6.3 Build nixcloud configuration to verify no regressions
- [x] 6.4 Update `docs/src/modules/nixos/server/proxy.md` with extension architecture section, API reference (`config` function signature, `globalConfig` function signature, `_resolvedExtraConfig`, `consumesExtraConfig`, `_name`, native options merging pattern, auto-enable pattern), priority ranges, and authoring guide
- [x] 6.5 Run `nix fmt .` and `nix flake check` to confirm everything passes (flake check: nixai pre-existing unrelated webhook error, nixcloud ✅, nixio pre-existing unrelated)

## 7. Migrate L4 to Extension

- [x] 7.1 Create `modules/nixos/server/proxy/extensions/l4.nix` that:
  - Declares per-vhost `options.server.proxy.virtualHosts` as `attrsOf (submodule ...)` with `options.l4` (nullOr submodule with listenPort: port, config: str default "")
  - Registers `server.proxy.extensions.l4` with priority 10, consumesExtraConfig=false
  - Sets `enable = mkDefault` (checks all hosts via getAllAttrsFunc: any vhost has l4 != null)
  - `config` function returns `""`
  - `globalConfig` function: collects L4 entries via collectAllAttrsFunc, applies replaceLocalHost to config strings, groups by listenPort, generates layer4 {} block (single-entry-per-port uses named format, multi-entry uses matcher-based routing)
  - Module `config` block: when isThisIOPrimaryHost and extension enabled, opens firewall TCP/UDP ports for unique listenPorts

- [x] 7.2 Import L4 extension in `proxy/default.nix`: `(importModule ./extensions/l4.nix { inherit proxyLib; })`

- [x] 7.3 Remove `l4` option declaration from `options.nix` (lines 168-184: the l4 mkOption block in vhost submodule options)

- [x] 7.4 Remove `l4Config` let-binding from `config.nix` (lines 45-90: the entire l4Config = let ... in ... block)

- [x] 7.5 Remove `layer4 {}` block wrapping from `config.nix` globalConfig (line 202: remove `layer4 { ... }` wrapping, leaving only `${extGlobalConfig}`)

- [x] 7.6 Remove L4 firewall port handling from `config.nix` (lines 270-285: the l4Ports let binding and allowedTCPPorts/allowedUDPPorts assignments)

- [x] 7.7 Remove the now-unused `sanitiseMatcherName` from `config.nix` (hasSuffix still used by ACME certs, kept)

- [x] 7.8 Build nixcloud configuration (✓ passed), nixio has pre-existing unrelated error (ai-agent.nix:42 missing webhook)

- [x] 7.9 Build nixcloud configuration: ✓ passed

- [x] 7.10 Run `nix fmt .` on all changed files (no changes needed)

- [x] 7.11 Update `docs/src/modules/nixos/server/proxy.md` (L4 in Migrated Extensions table, config.nix note, Layer 4 Forwarding section updated)
  - Add L4 to the "Migrated Extensions" table: `| l4 | 10 | L4 TCP/UDP forwarding (layer4 Caddy block + firewall ports) |`
  - Update the "config.nix — Caddy Integration" section: remove L4 mention, note that L4 is now an extension
  - Update "Layer 4 Forwarding" section: note it's managed by the L4 extension
