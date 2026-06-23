## Context

The proxy module (`modules/nixos/server/proxy/`) manages Caddy virtual hosts through a layered architecture:
- `options.nix` declares submodule options on each virtual host (e.g., auth method configs)
- Auth-specific modules (`kanidm.nix` for OAuth2, this new module for API keys) generate caddy-security global config blocks injected into `services.caddy.globalConfig`
- `config.nix` reads those options to emit per-vhost `extraConfig` (matchers, routes, authorize directives)
- `default.nix` imports all sub-modules and builds the `proxyLib` helper namespace

caddy-security (v1.1.31, already a caddy plugin in the nixio host) supports `authorize` blocks with header matchers. The `with` directive can validate `http.request.header.Req-API-Key` against a static value loaded from an environment variable.

The sops secrets pattern in this repo uses hierarchical naming like `PROXY_AUTH/<VHOST_NAME>_API_KEY`. Caddy reads env vars from a systemd `EnvironmentFile` or inline `{env.VAR}` placeholders.

## Goals / Non-Goals

**Goals:**
- Add `requireApiKey` as an opt-in submodule on any virtual host, following the proxy module's established auth extension pattern (options → global config → per-vhost extraConfig)
- Auto-generate one sops secret per vhost at `PROXY_AUTH/<VHOST_NAME>_API_KEY`
- Generate caddy-security `authorize` blocks per vhost validating `Req-API-Key` header
- Support optional `bypassPaths` to skip auth for specific paths
- Minimal new code — reuse existing proxyLib helpers pattern

**Non-Goals:**
- No Kanidm provisioning integration (api-key auth is orthogonal to OAuth2)
- No multi-key, key rotation, or revocation mechanism
- No rate limiting or brute-force protection
- No per-path different keys (one key per vhost)
- No admin dashboard or key management UI

## Decisions

### Decision 1: New module `api-key-auth.nix` instead of adding to an existing auth module

**Rationale:** API key auth is a distinct mechanism from OAuth2-based auth. A dedicated module keeps the implementation focused — it only generates `authorize` blocks with header matchers, with no need for identity providers, authentication portals, or authorization policies. Keeping it separate avoids conditional branches inside existing auth modules.

**Alternatives considered:** Adding api-key logic inside the existing OAuth2 auth module (`kanidm.nix`). Rejected — convolutes separate concerns and adds `if/else` branches in the generate functions for two unrelated auth mechanisms.

### Decision 2: `{env.API_KEY_<VHOST>}` placeholder + systemd `LoadCredential`

**Rationale:** caddy-security reads `with` match values from env vars via `{env.VAR}`. We'll set up systemd `LoadCredential` for `services.caddy.serviceConfig` pointing to the sops secret path. Uses same pattern as existing secret handling (e.g., `zeroclaw`). Avoids baking secrets into the Nix store.

**Alternatives considered:** Using `EnvironmentFile`. Rejected — `LoadCredential` is the modern systemd approach and avoids exposing secrets in /proc.

### Decision 3: Secret path naming: `PROXY_AUTH/<VHOST_NAME>_API_KEY`

**Rationale:** Consistent with existing patterns (`AI_AGENT/...`, `KANIDM/OAUTH2/...`). The vhost name is the subdomain key (e.g., `radarr` for `radarr.racci.dev`). Dots and hyphens replaced with underscores for valid env var names.

### Decision 4: `requireApiKey` as a submodule (not a bool)

**Rationale:** Future-proofing. A bool would lock us out of adding options like `bypassPaths` later without a breaking change. The submodule starts with `enable` + `bypassPaths`, consistent with how other auth extensions in the proxy module expose configuration as a submodule rather than a flat toggle.

## Risks / Trade-offs

- **One key per vhost** → If compromised, entire vhost exposed. Mitigation: same risk as any static API key. Document that users should rotate via `sops edit`.
- **No HMAC/derived-key scheme** → Key stored as plaintext env var in caddy process memory. Mitigation: acceptable for internal-only services behind Tailscale/WireGuard. Document as a constraint.
- **caddy-security version lock** → If plugin API changes, our `authorize` block syntax may break. Mitigation: version pinned via `caddy.withPlugins` in nixio host, explicit hash.
- **No mutual exclusivity check with other auth methods** → A vhost could have both `requireApiKey` and another auth extension enabled. Both would inject competing `route` and `authorize` directives into `extraConfig`, producing undefined behavior. Mitigation: add assertion that `requireApiKey` and other auth methods are mutually exclusive.

## Open Questions

- Should `requireApiKey` be mutually exclusive with other auth methods on the same vhost? (Lean: yes — multiple auth methods on one vhost would produce conflicting routing directives in the generated extraConfig. Add assertion.)
- Should the secret be readable by `caddy` user only? (Yes, owner `caddy` with mode `0400` to match the principle of least privilege for sops-managed secrets.)
