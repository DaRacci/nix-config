## 1. Extension Registry Foundation

- [ ] 1.1 Add `server.proxy.extensions` option in `options.nix` (attrsOf submodule with priority, enable, consumesExtraConfig, config, globalConfig, vhostModule)
- [ ] 1.2 Update vhost submodule in `options.nix` to collect `vhostModule` from all enabled extensions and include them in its `imports`
- [ ] 1.3 Add `_name` read-only option to the vhost submodule in `options.nix`
- [ ] 1.4 Add `server.proxy.virtualHosts.<name>.extensions` option in `options.nix` (nullOr listOf str, default null)
- [ ] 1.5 Create `modules/nixos/server/proxy/extensions/` directory
- [ ] 1.6 Add `getExtensionsForVhost` function to `proxyLib` in `default.nix`: filters by vhost whitelist, filters by enable, sorts by priority (ascending, alphabetical tie-break), returns sorted list
- [ ] 1.7 Add `getGlobalConfigFromExtensions` function to `proxyLib`: collects `globalConfig` from all enabled extensions, sorted by priority, concatenated
- [ ] 1.8 Add assertion: vhost whitelist names must exist in the registry (error if nonexistent extension name referenced)
- [ ] 1.9 Add assertion: at most one extension with `consumesExtraConfig = true` per vhost
- [ ] 1.10 Add assertion: vhost with `kanidm != null` and `extensions = []` raises a warning

## 2. Migrate Kanidm to Extension (vhost options + config + globalConfig)

- [ ] 2.1 Move `kanidm` option declaration from `options.nix` vhost submodule into `vhostModule` set by `extensions/kanidm.nix` (options path relative: `options.kanidm`)
- [ ] 2.2 Move `kanidmContexts` option declaration from `options.nix` into `extensions/kanidm.nix`'s own `options` block
- [ ] 2.3 Create `modules/nixos/server/proxy/extensions/kanidm.nix` that registers `server.proxy.extensions.kanidm` with: priority 50, consumesExtraConfig=true, `enable = mkDefault proxyLib.hasAnyKanidm`, config function returning auth directives or "", globalConfig function returning the `security { ... }` block (identity providers, portals, policies), vhostModule declaring `options.kanidm`
- [ ] 2.4 The kanidm extension's config function (name -> vh -> hostCfg) uses `resolveKanidmContext` from proxyLib, returns `""` when `vh.kanidm == null`
- [ ] 2.5 When `vh.kanidm != null`: config function generates bypass handle + auth handle structure, wrapping `vh._resolvedExtraConfig` inside both handles, using `vh._name` for portal/policy references
- [ ] 2.6 Move the security block generation logic from `kanidm.nix` into the kanidm extension's `globalConfig` function
- [ ] 2.7 Import kanidm extension in `proxy/default.nix` via `importModule`, remove old `kanidm.nix` import
- [ ] 2.8 Delete `modules/nixos/server/proxy/kanidm.nix` (all logic moved to extension)
- [ ] 2.9 Rewrite `config.nix` vhost `extraConfig` generation: resolve `_resolvedExtraConfig` on each vhost, call `getExtensionsForVhost`, iterate extensions calling their config functions, check `consumesExtraConfig` to decide whether to append raw `extraConfig`
- [ ] 2.10 Rewrite `config.nix` globalConfig generation: call `getGlobalConfigFromExtensions`, concatenate into `services.caddy.globalConfig`
- [ ] 2.11 Remove the old `optionalString (vh.kanidm != null)` block in `config.nix` (replaced by extension)

## 3. Migrate Dashboard to Extension

- [ ] 3.1 Create `modules/nixos/server/proxy/extensions/dashboard.nix` that: registers `server.proxy.extensions.dashboard` with priority 200, sets `enable = mkDefault (cfg.virtualHosts != {})`, config function returns `""`, globalConfig returns `""`, vhostModule = null
- [ ] 3.2 Move `server.dashboard.items` generation from `extensions.nix` to dashboard extension's module config block
- [ ] 3.3 Import dashboard extension in `proxy/default.nix`

## 4. Migrate Cloudflared to Extension

- [ ] 4.1 Create `modules/nixos/server/proxy/extensions/cloudflared.nix` that: registers `server.proxy.extensions.cloudflared` with priority 200, sets `enable = mkDefault (any vhost has public == true)`, config function returns `""`, globalConfig returns `""`, vhostModule = null
- [ ] 4.2 Move `services.cloudflared.tunnels` ingress generation from `extensions.nix` to cloudflared extension's module config block
- [ ] 4.3 Import cloudflared extension in `proxy/default.nix`

## 5. Clean up Original extensions.nix

- [ ] 5.1 Rename `modules/nixos/server/proxy/extensions.nix` to `modules/nixos/server/proxy/kanidm-provisioning.nix` (retains only Kanidm provisioning: sops secrets + oauth2 systems)
- [ ] 5.2 Update import in `proxy/default.nix` from `./extensions.nix` to `./kanidm-provisioning.nix`

## 6. Validate and Document

- [ ] 6.1 Run `nix fmt .` on all changed files
- [ ] 6.2 Build nixio configuration to verify no regressions
- [ ] 6.3 Build nixcloud configuration to verify no regressions
- [ ] 6.4 Update `docs/src/modules/nixos/server/proxy.md` with extension architecture section, API reference (`config` function signature, `globalConfig` function signature, `_resolvedExtraConfig`, `consumesExtraConfig`, `_name`, `vhostModule` for option injection, auto-enable pattern), priority ranges, and authoring guide
- [ ] 6.5 Run `nix fmt .` and `nix flake check` to confirm everything passes
