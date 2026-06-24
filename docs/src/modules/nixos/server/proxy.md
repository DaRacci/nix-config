# Proxy Submodule

The Proxy submodule provides a unified interface for exposing internal services through Caddy. It handles virtual host configuration, automatic SSL via ACME, OAuth2 authentication with Kanidm, and public exposure through Cloudflared tunnels.

## Purpose

This module abstracts the complexity of reverse proxying by allowing services to define their proxy requirements within their own module configuration. It automatically coordinates between backend hosts and the primary IO host to ensure ports are open and traffic is correctly routed.

## Options

{{#include ../../../../generated/server-proxy-options.md}}

## Per-Module Examples

### `default.nix` - Logic and Helpers

This file contains the internal logic for resolving OAuth contexts and mapping local addresses to backend hostnames.

```nix
# Example: How contextToEnvPrefix transforms names for environment variables
contextToEnvPrefix "my-service" # Returns "MY_SERVICE"
```

### `options.nix` - Option Definitions

Defines the structure of virtual hosts and shared contexts.

```nix
server.proxy.kanidmContexts.admin-apps = {
  authDomain = "auth.internal.example.com";
  allowGroups = [ "admins@auth.example.com" ];
};

server.proxy.virtualHosts.grafana = {
  public = true;
  kanidm = {
    context = "admin-apps";
    allowGroups = [ "grafana-users@auth.example.com" ];
    bypassPaths = [ "/health" ];
  };
  extraConfig = "reverse_proxy localhost:3000";
};
```

### `config.nix` - Caddy Integration

Handles the generation of `services.caddy.virtualHosts` and ACME certificate requests.

> **Note:** L4 (TCP/UDP) forwarding is handled by the `l4` extension, not by config.nix. See [Layer 4 Forwarding](#layer-4-forwarding).

```nix
# Generated Caddy block for a vhost with Kanidm
grafana.example.com {
    import default
    import public

    @bypass_auth_grafana path /health
    handle @bypass_auth_grafana {
        reverse_proxy 10.0.0.5:3000
    }

    route /auth/* {
        authenticate with grafana_portal
    }
    handle {
        authorize with grafana_policy
        reverse_proxy 10.0.0.5:3000
    }
}
```

### `kanidm.nix` - Authentication Security

Generates the Caddy `security` block, including identity providers, portals, and authorization policies.

```nix
security {
    oauth identity provider admin-apps {
        realm admin-apps
        client_id "admin-apps"
        client_secret {env.OAUTH_ADMIN_APPS_CLIENT_SECRET}
        metadata_url https://auth.internal.example.com/oauth2/openid/admin-apps/.well-known/openid-configuration
    }
    # ... portals and policies
}
```

### `extensions.nix` - System Integration

Connects the proxy to the dashboard, Cloudflared tunnels, and automates Kanidm client provisioning.

```nix
# Automatic Kanidm provisioning based on proxy config
services.kanidm.provision.systems.oauth2.admin-apps = {
    displayName = "Admin Apps";
    originUrl = [ "https://grafana.example.com/auth/oauth2/admin-apps/authorization-code-callback" ];
    # ...
};
```

## Operational Notes

### Caddy Integration

The module assumes the existence of a `default` Caddy snippet for common headers and security settings. When `public` is enabled, it also expects a `public` snippet.

### Dashboard Integration

Services defined in `server.proxy.virtualHosts` are automatically added to the server dashboard with default titles and icons derived from the host name.

### Kanidm OAuth2 Context

Authentication requires specific secrets per context, managed via sops-nix:

1. `KANIDM/OAUTH2/<UPPER_CONTEXT>_SECRET`: Provisioning secret for Kanidm systems.
1. `OAUTH_<PREFIX>_CLIENT_SECRET`: The OAuth2 client secret for Caddy.
1. `<PREFIX>_SHARED_KEY`: A shared key used by Caddy to sign and verify authentication tokens.

These are automatically managed if Kanidm provisioning is enabled on the same host.

### Layer 4 Forwarding

L4 forwarding uses the `caddy.layer4` plugin for non-HTTP traffic like database connections or SSH. Managed by the `l4` extension (`modules/nixos/server/proxy/extensions/l4.nix`), which auto-enables when any vhost has `l4 != null`.

## References

- [Kanidm OAuth2 Documentation](https://kanidm.github.io/kanidm/master/integrations/oauth2.html)
- [Caddy Security Plugin](https://github.com/greenpau/caddy-security)
- [Caddy Layer 4 Plugin](https://github.com/mholt/caddy-l4)

## Extension Architecture

The proxy module supports a registry-based extension system. Extensions are self-contained modules that inject Caddy directives into virtual host configurations — without modifying proxy internals.

### Extension Registry

Extensions register themselves via `server.proxy.extensions.<name>`, an attribute set of submodules. Each extension has:

| Field                 | Type                                             | Default  | Description                                                                                                               |
| --------------------- | ------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| `priority`            | `int`                                            | `100`    | Lower values = earlier Caddy config placement. Ranges: 0-49 reserved, 50-99 auth, 100-199 general, 200+ post-processing   |
| `enable`              | `bool`                                           | `false`  | Globally enabled. Set via `mkDefault` based on detected config                                                            |
| `consumesExtraConfig` | `bool`                                           | `false`  | When `true`, the extension embeds `vh._resolvedExtraConfig` in its output. `config.nix` skips appending raw `extraConfig` |
| `config`              | `vhostName -> vhostAttrSet -> hostConfig -> str` | required | Per-vhost Caddy directive generator                                                                                       |
| `globalConfig`        | `hostConfig -> str`                              | `_ → ""` | Top-level Caddy `globalConfig` directives                                                                                 |
| `vhostModule`         | `nullOr deferredModule`                          | `null`   | Per-vhost option declarations                                                                                             |

### Per-Vhost Extension Selection

Each vhost has `server.proxy.virtualHosts.<name>.extensions` (default `null` = all enabled extensions). Set to a list of extension names for selective enablement, or `[]` to disable all extensions.

### Config Function Signature

```nix
config :: vhostName -> vhostAttrSet -> hostConfig -> string
```

Arguments:

- `vhostName` (`str`): The vhost's attribute name (e.g., `"grafana"`)
- `vhostAttrSet`: The full vhost attribute set, including `_resolvedExtraConfig` (user's `extraConfig` with `replaceLocalHost` applied) and `_name`
- `hostConfig`: Full host-level NixOS config

The vhost attrset contains `_resolvedExtraConfig` — the user's `extraConfig` field with `localhost`/`127.0.0.1` already replaced for non-IO hosts.

### GlobalConfig Function Signature

```nix
globalConfig :: hostConfig -> string
```

Called once per enabled extension on the IO primary host. Output concatenated into `services.caddy.globalConfig`, sorted by extension priority.

### Auto-Enable Pattern

Extensions auto-detect whether they have work to do using `mkDefault`:

```nix
server.proxy.extensions.myext.enable = mkDefault (
  # check if any vhost uses my extension's features
);
```

Users can force-disable with explicit `enable = false`.

### Priority Ordering

Extensions sort by priority ascending. Equal priorities break alphabetically by extension name. Extensions with lower priority numbers generate config earlier.

### Authoring a New Extension

1. Create file: `modules/nixos/server/proxy/extensions/<name>.nix`
1. Import in `proxy/default.nix`: `(importModule ./extensions/<name>.nix { inherit proxyLib; })`
1. Set `server.proxy.extensions.<name>` with priority, config function, etc.
1. Declare per-vhost options via `options.server.proxy.virtualHosts` with `attrsOf (submodule ...)`
1. Use `proxyLib` for helpers: `replaceLocalHost`, `resolveKanidmContext`, `hasAnyKanidm`

Example skeleton:

```nix
{ proxyLib, ... }:
{ config, lib, ... }:
let
  inherit (lib) mkOption types mkDefault;
in
{
  options.server.proxy.virtualHosts = mkOption {
    type = attrsOf (submodule ({ name, ... }: {
      options.mycustom = mkOption {
        type = bool;
        default = false;
      };
    }));
  };

  config = {
    server.proxy.extensions.mycustom = {
      priority = 75;
      config = name: vh: hostCfg:
        if !vh.mycustom then "" else "header X-Custom on";
      globalConfig = hostCfg: "";
      vhostModule = null;
    };
  };
}
```

### Migrated Extensions

| Extension     | Priority | Purpose                                                     |
| ------------- | -------- | ----------------------------------------------------------- |
| `l4`          | 10       | L4 TCP/UDP forwarding (layer4 Caddy block + firewall ports) |
| `kanidm`      | 50       | Kanidm OAuth2 authentication per vhost                      |
| `dashboard`   | 200      | Auto-generate dashboard items                               |
| `cloudflared` | 200      | Cloudflared tunnel ingress                                  |
