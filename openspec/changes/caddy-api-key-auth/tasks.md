## 1. Module Scaffolding

- [ ] 1.1 Create `modules/nixos/server/proxy/api-key-auth.nix` with empty `{ config, lib, ... }` module structure, receiving proxyLib via the file-argument pattern and following the proxy module's standard layout (let block for lib bindings, helper functions, then config section)
- [ ] 1.2 Import `api-key-auth.nix` in `modules/nixos/server/proxy/default.nix` alongside the other proxy sub-modules

## 2. Options

- [ ] 2.1 Add `requireApiKey` submodule option to `virtualHosts.<name>` in `modules/nixos/server/proxy/options.nix` with `enable` (bool, default false), `bypassPaths` (listOf str, default [ ])

## 3. API Key Auth Module Implementation

- [ ] 3.1 Implement `collectApiKeyVirtualHosts` helper: collect all vhosts with `requireApiKey.enable = true` across all hosts using `collectAllAttrsFunc`
- [ ] 3.2 Implement `hasAnyApiKey` helper: boolean check for any api-key vhosts
- [ ] 3.3 Implement `generateAuthorizationBlocks`: generate caddy-security `authorize` blocks per vhost using `with http.request.header.Req-API-Key {env.API_KEY_<VHOST>}`
- [ ] 3.4 Register `order authorize before reverse_proxy` in `services.caddy.globalConfig` when any api-key vhosts exist, using `mkBefore` so the directive merges safely with order directives from other modules
- [ ] 3.5 Generate sops secrets: `sops.secrets."PROXY_AUTH/<VHOST_NAME>_API_KEY"` for each api-key vhost

## 4. Vhost ExtraConfig Integration

- [ ] 4.1 In `config.nix`, add conditional block for `requireApiKey` in vhost extraConfig: a named matcher for bypass paths that routes to the backend directly, a `route /auth/apikey/*` for the authorize flow, and `authorize with <name>_apikey` in the default handle wrapping the vhost's extraConfig

## 5. Mutual Exclusivity Assertion

- [ ] 5.1 Add Nix assertion in `api-key-auth.nix`: vhost SHALL NOT have `requireApiKey.enable = true` when another proxy auth method is also enabled on that vhost (e.g., `kanidm != null`), since both inject competing route/authorize directives

## 6. Build Verification

- [ ] 6.1 Run `nix build .#nixosConfigurations.nixio.config.system.build.toplevel` to verify the nixio host (primary IO host) builds successfully
- [ ] 6.2 Run `nix fmt .` and verify clean format
