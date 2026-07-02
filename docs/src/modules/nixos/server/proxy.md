# Server Proxy — Unified Caddy Reverse Proxy

## Purpose

The Proxy submodule provides a unified interface for exposing internal services through Caddy. It handles virtual host configuration, automatic SSL via ACME, OAuth2 authentication with Kanidm, static API key authentication, and public exposure through Cloudflared tunnels. It abstracts the complexity of reverse proxying by allowing services to define their proxy requirements within their own module configuration, automatically coordinating between backend hosts and the primary IO host to ensure ports are open and traffic is correctly routed.

## Entry Point

- **Main file**: `modules/nixos/server/proxy/default.nix`
- **Supporting file**: `modules/nixos/server/proxy/options.nix`
- **Supporting file**: `modules/nixos/server/proxy/config.nix`
- **Supporting file**: `modules/nixos/server/proxy/kanidm.nix`
- **Supporting file**: `modules/nixos/server/proxy/extensions.nix`
- **Supporting file**: `modules/nixos/server/proxy/extensions/l4.nix`

#### Options

{{#include ../../../../generated/server-proxy-options.md}}

## Architecture / Services / Scope

### File Layout

- **`default.nix`** — Logic and helpers: resolving OAuth contexts and mapping local addresses to backend hostnames.
- **`options.nix`** — Option definitions for virtual hosts and shared contexts.
- **`config.nix`** — Caddy integration: generation of `services.caddy.virtualHosts` and ACME certificate requests. L4 (TCP/UDP) forwarding is handled by the `l4` extension, not by `config.nix`.
- **`kanidm.nix`** — Authentication security: generates the Caddy `security` block, including identity providers, portals, and authorization policies.
- **`extensions.nix`** — System integration: connects the proxy to the dashboard, Cloudflared tunnels, and automates Kanidm client provisioning.

### Extension System

The proxy module supports a registry-based extension system. Extensions are self-contained modules that inject Caddy directives into virtual host configurations — without modifying proxy internals.

#### Extension Registry

Extensions register themselves via `server.proxy.extensions.<name>`, an attribute set of submodules. Each extension has:

| Field                 | Type                                             | Default  | Description                                                                                                               |
| --------------------- | ------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| `priority`            | `int`                                            | `100`    | Lower values = earlier Caddy config placement. Ranges: 0-49 reserved, 50-99 auth, 100-199 general, 200+ post-processing   |
| `enable`              | `bool`                                           | `false`  | Globally enabled. Set via `mkDefault` based on detected config                                                            |
| `consumesExtraConfig` | `bool`                                           | `false`  | When `true`, the extension embeds `vh._resolvedExtraConfig` in its output. `config.nix` skips appending raw `extraConfig` |
| `config`              | `vhostName -> vhostAttrSet -> hostConfig -> str` | required | Per-vhost Caddy directive generator                                                                                       |
| `globalConfig`        | `hostConfig -> str`                              | `_ → ""` | Top-level Caddy `globalConfig` directives                                                                                 |
| `vhostModule`         | `nullOr deferredModule`                          | `null`   | Per-vhost option declarations                                                                                             |

#### Per-Vhost Extension Selection

Each vhost has `server.proxy.virtualHosts.<name>.extensions` (default `null` = all enabled extensions). Set to a list of extension names for selective enablement, or `[]` to disable all extensions.

#### Config Function Signature

```nix
config :: vhostName -> vhostAttrSet -> hostConfig -> string
```

Arguments:

- `vhostName` (`str`): The vhost's attribute name (e.g., `"grafana"`).
- `vhostAttrSet`: The full vhost attribute set, including `_resolvedExtraConfig` (user's `extraConfig` with `replaceLocalHost` applied) and `_name`.
- `hostConfig`: Full host-level NixOS config.

#### GlobalConfig Function Signature

```nix
globalConfig :: hostConfig -> string
```

Called once per enabled extension on the IO primary host. Output concatenated into `services.caddy.globalConfig`, sorted by extension priority.

#### Auto-Enable Pattern

Extensions auto-detect whether they have work to do using `mkDefault`; users can force-disable with explicit `enable = false`.

#### Priority Ordering

Extensions sort by priority ascending. Equal priorities break alphabetically by extension name. Extensions with lower priority numbers generate config earlier.

#### Authoring a New Extension

1. Create file: `modules/nixos/server/proxy/extensions/<name>.nix`
1. Import in `proxy/default.nix`.
1. Set `server.proxy.extensions.<name>` with priority, config function, etc.
1. Declare per-vhost options via `options.server.proxy.virtualHosts` with `attrsOf (submodule ...)`.
1. Use `proxyLib` for helpers: `replaceLocalHost`, `resolveKanidmContext`, `hasAnyKanidm`.

### API Key Auth Extension

The `api-key-auth` extension provides static API key authentication for virtual hosts. When enabled, requests must include a valid `Req-API-Key` header matching a securely generated secret. Bypass paths are supported per vhost. Mutual exclusivity with Kanidm on the same vhost is enforced by the existing `consumesExtraConfig` assertion.

### Migrated Extensions

| Extension      | Priority | Purpose                                                     |
| -------------- | -------- | ----------------------------------------------------------- |
| `l4`           | 10       | L4 TCP/UDP forwarding (layer4 Caddy block + firewall ports) |
| `kanidm`       | 50       | Kanidm OAuth2 authentication per vhost                      |
| `api-key-auth` | 50       | Static API key authentication per vhost (with bypass paths) |
| `dashboard`    | 200      | Auto-generate dashboard items                               |
| `cloudflared`  | 200      | Cloudflared tunnel ingress                                  |

## Secrets

### Kanidm OAuth2 Context

Authentication requires specific secrets per context, managed via sops-nix:

1. `KANIDM/OAUTH2/<UPPER_CONTEXT>_SECRET`: Provisioning secret for Kanidm systems.
1. `OAUTH_<PREFIX>_CLIENT_SECRET`: The OAuth2 client secret for Caddy.
1. `<PREFIX>_SHARED_KEY`: A shared key used by Caddy to sign and verify authentication tokens.

These are automatically managed if Kanidm provisioning is enabled on the same host.

### API Key Auth

Secrets are auto-generated via sops at `PROXY_AUTH/<VHOST_NAME>_API_KEY`, injected via systemd `LoadCredential`.

## Operational Notes / Assumptions

- **Caddy Integration**: The module assumes the existence of a `default` Caddy snippet for common headers and security settings. When `public` is enabled, it also expects a `public` snippet.
- **Dashboard Integration**: Services defined in `server.proxy.virtualHosts` are automatically added to the server dashboard with default titles and icons derived from the host name.
- **Layer 4 Forwarding**: L4 forwarding uses the `caddy.layer4` plugin for non-HTTP traffic like database connections or SSH. Managed by the `l4` extension (`modules/nixos/server/proxy/extensions/l4.nix`), which auto-enables when any vhost has `l4 != null`.

## References

- [Kanidm OAuth2 Documentation](https://kanidm.github.io/kanidm/master/integrations/oauth2.html)
- [Caddy Security Plugin](https://github.com/greenpau/caddy-security)
- [Caddy Layer 4 Plugin](https://github.com/mholt/caddy-l4)
