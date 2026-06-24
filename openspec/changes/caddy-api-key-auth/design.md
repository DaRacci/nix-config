## Context

The proxy module (`modules/nixos/server/proxy/`) now uses an extension registry architecture:

- `options.nix` declares the `server.proxy.extensions` attrset (submodules with `priority`, `enable`, `consumesExtraConfig`, `config`, `globalConfig`, `vhostModule`) and per-vhost extension selection (`extensions` list)
- Extension files live under `extensions/` and self-register by setting `server.proxy.extensions.<name>`
- Each extension declares its own vhost options via `options.server.proxy.virtualHosts.<name>.<ext>` — NixOS module system merges these natively
- `default.nix` imports all extension files via `importModule`, builds `proxyLib` helpers
- `config.nix` calls each enabled extension's `config` function per vhost, sorted by priority, and concatenates output into Caddy `extraConfig`
- Extensions with `consumesExtraConfig = true` embed the user's `extraConfig` inside their output; `config.nix` skips appending raw `extraConfig` afterward
- `config.nix` asserts at most one `consumesExtraConfig` extension per vhost (mutual exclusivity)
- Global config is collected via `globalConfig` functions, also sorted by priority

caddy-security (v1.1.31, already a caddy plugin in the nixio host) supports `authorize` blocks that can reference named Caddy matchers via `with @<matcher_name>`. The matcher itself is a standard Caddy `@name { header ... }` block that performs the actual header validation.

The sops secrets pattern in this repo uses hierarchical naming like `PROXY_AUTH/<VHOST_NAME>_API_KEY`. Caddy reads env vars via `{env.VAR}` placeholders. systemd `LoadCredential` is the established pattern for loading secrets.

## Goals / Non-Goals

**Goals:**
- Implement API key auth as a self-registering proxy extension, following the established extension authoring pattern (kanidm extension is the reference)
- Add `requireApiKey` as an opt-in submodule option on virtual hosts, declared by the extension itself
- Auto-enable the extension via `mkDefault` when any vhost has `requireApiKey.enable = true`
- Auto-generate one sops secret per vhost at `PROXY_AUTH/<VHOST_NAME>_API_KEY`
- Generate caddy-security `authorize` blocks per vhost validating `Req-API-Key` header
- Support optional `bypassPaths` to skip auth for specific paths
- Rely on existing `consumesExtraConfig` assertion for mutual exclusivity with kanidm extension
- Minimal changes — one new file, one import line in `default.nix`

**Non-Goals:**
- No Kanidm provisioning integration (api-key auth is orthogonal to OAuth2)
- No multi-key, key rotation, or revocation mechanism
- No rate limiting or brute-force protection
- No per-path different keys (one key per vhost)
- No admin dashboard or key management UI

## Decisions

### Decision 1: Extension file in `extensions/api-key-auth.nix` following established pattern

**Rationale:** The proxy module's extension registry is the standard mechanism for adding auth features. All existing integrations (kanidm, l4, cloudflared, dashboard) follow this pattern. A new extension file with no changes to core proxy files minimizes risk and keeps the implementation self-contained.

**Alternatives considered:** Adding API key logic inside the existing kanidm extension or creating a separate module outside the registry. Rejected — kanidm and API key auth are orthogonal auth mechanisms; mixing them adds unnecessary branching. The registry is the intended extension point.

### Decision 2: `consumesExtraConfig = true` for mutual exclusivity with kanidm

**Rationale:** Both kanidm and api-key-auth embed `_resolvedExtraConfig` inside their Caddy handle blocks. If both were active on the same vhost, their competing `authorize` directives and handle blocks would produce undefined behavior. Since both set `consumesExtraConfig = true`, the existing assertion in `config.nix` (vhostsWithMultipleConsumers) already prevents this — no custom assertion needed. Users resolve the conflict by either not configuring both auth methods on one vhost, or by whitelisting only one extension via `extensions`.

**Alternatives considered:** Adding a separate assertion in the api-key-auth module checking `vh.kanidm != null`. Rejected — redundant; the existing `consumesExtraConfig` assertion is more general and already covers any future auth extensions.

### Decision 3: Named Caddy matcher for header validation + caddy-security `with @matcher`

**Rationale:** caddy-security's `with` directive inside `authorize` blocks supports references to named Caddy matchers (e.g., `with @my_matcher`), but does NOT support inline header matcher syntax like `with http.request.header.X`. The validation is therefore split across two locations:
- **Per-vhost `config` function**: emits `@<name>_apikey_key { header Req-API-Key {env.API_KEY_<VHOST>} }` — a named Caddy matcher that checks the header value
- **`globalConfig` function**: emits `authorize with <name>_apikey_authorizer { with @<name>_apikey_key }` — references the named matcher

This is consistent with how Caddy named matchers wire into caddy-security's `authorize` blocks.

**Alternatives considered:** Inline `with http.request.header.Req-API-Key {env.VAR}`. Rejected — not valid caddy-security syntax; the `with` directive only accepts `@matcher` references, `expression`, or auth method keywords like `basic auth` / `api key auth`.

### Decision 4: `{env.API_KEY_<VHOST>}` placeholder + systemd `LoadCredential`

**Rationale:** caddy-security reads `with` match values from env vars via `{env.VAR}`. Using systemd `LoadCredential` (same pattern as existing secret handling) avoids baking secrets into the Nix store and keeps secrets out of `/proc`.

**Alternatives considered:** Using `EnvironmentFile`. Rejected — `LoadCredential` is the modern systemd approach and avoids exposing secrets in /proc.

### Decision 5: Secret path naming: `PROXY_AUTH/<VHOST_NAME>_API_KEY`

**Rationale:** Consistent with existing patterns (`AI_AGENT/...`, `KANIDM/OAUTH2/...`). The vhost name is the subdomain key (e.g., `radarr`). Non-alphanumeric characters replaced with underscores. The environment variable uses the uppercased, underscore-normalized form: `API_KEY_<VHOST>`.

### Decision 6: Extension priority 50, same range as kanidm

**Rationale:** Priority range 50-99 is designated for auth extensions. Since `consumesExtraConfig` prevents both from running on the same vhost, equal priority has no practical ordering consequence. If a future auth extension with different priority coexists with one of them, the priority ordering determines config placement.

### Decision 7: `requireApiKey` as a submodule (not a bool)

**Rationale:** Future-proofing. A bool would prevent adding options like `bypassPaths` later without a breaking change. The submodule starts with `enable` + `bypassPaths`, consistent with how kanidm exposes a submodule rather than a flat toggle.

## Risks / Trade-offs

- **One key per vhost** → If compromised, entire vhost exposed. Mitigation: same risk as any static API key. Document that users should rotate via `sops edit`.
- **Plaintext key in caddy process memory** → Key loaded via env var, readable by root/caddy-user from `/proc/<pid>/environ`. Attacker with that level of access can also read the sops secret file. For services exposed via public Cloudflared tunnels, the operational hardening recommendations below apply.
- **caddy-security version lock** → If plugin API changes, our `authorize` block syntax may break. Mitigation: version pinned via `caddy.withPlugins` in nixio host, explicit hash.

### No HMAC/Derived-Key Support in Available Plugins

An HMAC-derived key scheme (where caddy holds `HMAC-SHA256(real-key, salt)` instead of the real key) would prevent key extraction from process memory. However, no maintained Caddy plugin supports this for header-based API key validation:

| Approach | Feasibility |
|----------|-------------|
| caddy-security `with` directive | Only `basic auth` / `api key auth` portal-based flows. No hash/derived-key matchers. |
| Caddy CEL `expression` matcher | `sha256()` supported but no built-in HMAC. Still plaintext at comparison point. |
| `forward_auth` to external service | Works (delegate validation to sidecar). Adds latency + new service to maintain. |
| Custom Caddy Go module | Cleanest architecture but requires xcaddy rebuild on every Caddy update. |
| Asymmetric JWT (Ed25519) | Correct cryptographic primitive — private key stays in sops, public key only in caddy. But no simple JWT header-validator plugin exists; still needs `forward_auth` or custom module. |

**Decision:** Ship with plaintext key validation + operational hardening. A future change can add `forward_auth` with asymmetric JWT validation as a separate extension or an enhancement to this one.

### Operational Hardening for Public-Facing Vhosts

- **Use long random keys**: 64-char alphanumeric hex (sufficient entropy, not brute-forceable)
- **Rotate regularly**: `sops edit` and redeploy
- **Monitor caddy access logs** for repeated 401 patterns
- **Consider rate limiting** as a follow-up openspec change (caddy `rate_limit` module already available)

## Open Questions

- Should `requireApiKey` be mutually exclusive with other auth methods on the same vhost? (Resolved: yes. Both extensions set `consumesExtraConfig = true`; the existing assertion in `config.nix` prevents coexistence. No additional code needed.)
- Should the secret be readable by `caddy` user only? (Yes, owner `caddy` with mode `0400` to match the principle of least privilege for sops-managed secrets.)
