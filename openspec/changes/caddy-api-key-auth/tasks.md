## 1. Extension Scaffolding

- [ ] 1.1 Create `modules/nixos/server/proxy/extensions/api-key-auth.nix` following the extension authoring pattern from kanidm/l4/cloudflared: receive `{ isThisIOPrimaryHost, collectAllAttrsFunc, getAllAttrsFunc, proxyLib, ... }:` file-argument, standard `{ config, lib, ... }:` module signature, let block for helpers, then `options` + `config` sections
- [ ] 1.2 Add import line in `modules/nixos/server/proxy/default.nix`: `(importModule ./extensions/api-key-auth.nix { inherit proxyLib; })`

## 2. Vhost Options

- [ ] 2.1 Declare `options.server.proxy.virtualHosts.<name>.requireApiKey` as `nullOr (submodule { enable (bool, default false), bypassPaths (listOf str, default []) })` — follows kanidm's vhost option declaration pattern
- [ ] 2.2 Default value is `null` (auth disabled unless explicitly configured)

## 3. Extension Self-Registration

- [ ] 3.1 Set `server.proxy.extensions.api-key-auth` with:
  - `priority = 50` (auth range, same as kanidm)
  - `consumesExtraConfig = true` (embeds `_resolvedExtraConfig` in output; triggers mutual exclusivity with kanidm via existing assertion)
  - `enable = mkDefault` — auto-enable when any vhost has `requireApiKey.enable = true`, using `getAllAttrsFunc` pattern
  - `vhostModule = null`

## 4. Per-Vhost Config Function

- [ ] 4.1 Implement `config` function (`name -> vh -> hostCfg -> string`):
  - Returns `""` if `vh.requireApiKey.enable != true`
  - Sanitizes vhost name (replace `-` `.` with `_`) for matcher names
  - Generates named caddy matcher `@<name>_apikey_key { header Req-API-Key {env.API_KEY_<VHOST>} }` — the header matcher used by the authorize block
  - Generates bypass matcher for `bypassPaths` (if non-empty): `@bypass_apikey_<name> path ...` + `handle @bypass_apikey_<name> { <resolvedExtraConfig> }`
  - Generates `route /auth/apikey/* { authorize with <name>_apikey_authorizer }`
  - Generates `handle { authorize with <name>_apikey_authorizer \n  <resolvedExtraConfig> }`
  - Follows same output structure as kanidm's config function (bypass → route → handle)

## 5. Global Config Function

- [ ] 5.1 Implement `globalConfig` function (`hostCfg -> string`):
  - `globalConfig` is already called only on IO primary host by `config.nix` (`mkIf isThisIOPrimaryHost`); no guard needed inside the function
  - Collects all vhosts with `requireApiKey.enable = true` using `collectAllAttrsFunc`
  - Returns `""` if no api-key vhosts exist
  - Generates `order authorize before reverse_proxy` directive **only when kanidm is not also emitting it** (check `!config.server.proxy.extensions.kanidm.enable` or `!hasAnyKanidm`). Avoids duplicate `order` directive when both auth extensions are globally enabled on different vhosts.
  - Generates per-vhost `authorize` blocks:
    ```
    authorize with <name>_apikey_authorizer {
      with @<name>_apikey_key
    }
    ```
  - The `@<name>_apikey_key` named matcher is defined in the per-vhost `config` function, not here. This block only references it.
  - Uses sanitised vhost name (replace `-` `.` with `_`) for consistency

## 6. Sops Secrets

- [ ] 6.1 Generate `sops.secrets` entries for each api-key vhost:
  - Path: `PROXY_AUTH/<VHOST_NAME>_API_KEY`
  - Owner: `caddy`, mode: `0400`
  - Guard with `mkIf` on extension being enabled AND host being IO primary (uses `isThisIOPrimaryHost`)
  - Collect vhosts using `collectAllAttrsFunc` pattern

## 7. systemd LoadCredential

- [ ] 7.1 Configure `systemd.services.caddy.serviceConfig.LoadCredential` for each api-key secret:
  - Credential name: `API_KEY_<VHOST>` (uppercased, underscore-normalized)
  - Path: `sops.secret."PROXY_AUTH/<VHOST_NAME>_API_KEY".path`
  - Guard with `mkIf` on extension being enabled AND host being IO primary (uses `isThisIOPrimaryHost`)

## 8. Build Verification

- [ ] 8.1 Run `nix build .#nixosConfigurations.nixio.config.system.build.toplevel` to verify the nixio host builds successfully
- [ ] 8.2 Run `nix fmt .` and verify clean format
- [ ] 8.3 Verify that enabling `requireApiKey` on a vhost that also has `kanidm != null` triggers the existing mutual exclusivity assertion
