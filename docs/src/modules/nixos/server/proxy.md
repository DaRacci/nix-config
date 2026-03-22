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

L4 forwarding uses the `caddy.layer4` plugin. It is primarily used for non-HTTP traffic like database connections or SSH.

Public services are routed through the Cloudflared tunnel with ID `8d42e9b2-3814-45ea-bbb5-9056c8f017e2`. Ensure this tunnel is correctly configured on the IO host.

## References

- [Kanidm OAuth2 Documentation](https://kanidm.github.io/kanidm/master/integrations/oauth2.html)
- [Caddy Security Plugin](https://github.com/greenpau/caddy-security)
- [Caddy Layer 4 Plugin](https://github.com/mholt/caddy-l4)
