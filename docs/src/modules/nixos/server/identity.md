# Server Identity — Managed Kanidm Identity Provider

## Purpose

The identity submodule provides a managed Kanidm identity provider for the server fleet. It handles Kanidm server configuration, ACME TLS certificate provisioning via Cloudflare DNS, automated online backups, OAuth2 client registration, group provisioning, and reverse proxy exposure.

This module was extracted and generalised from the old [nixcloud/identity.nix](../../../../hosts/server/nixcloud/identity.nix).

## Entry Point

- **Main file**: `server.identity` in [modules/nixos/server/identity/default.nix](../../../../modules/nixos/server/identity/default.nix).

### Options

{{#include ../../../../generated/server-identity-options.md}}

### Kanidm Provisioning

`server.identity.kanidm.groups` — attribute set of groups to provision on startup. Each group has:

- `members` (`listOf str`, default `[]`): Group members.

`server.identity.kanidm.oauth2` — attribute set of OAuth2 clients to register. Each attribute name is the client ID. Each client has:

- `displayName` (`str`): Display name for the OAuth2 client.
- `originUrl` (`str` or `listOf str`): Origin URL or list of URLs for callbacks.
- `originLanding` (`str`): Landing URL after OAuth2 login.
- `basicSecretFile` (`nullOr str`, default `null`): Path to the client basic secret file. Required for confidential (non-public) clients; public clients using PKCE should omit this (leave as `null`).
- `public` (`bool`, default `false`): Whether the client uses PKCE (public client).
- `scopeMaps` (`attrsOf (listOf str)`, default `{}`): Mapping of group names to allowed scopes.
- `claimMaps` (`attrsOf submodule`, default `{}`): Claim maps with `joinType` (`"array"` or `"csv"`) and `valuesByGroup`.

### Proxy Behaviour

When enabled, the module automatically registers a reverse proxy virtual host under `server.proxy.virtualHosts.auth`. This proxy forwards HTTPS traffic to the configured `bindAddress`.

### Dashboard Integration

A dashboard item is automatically added via `server.dashboard.items.auth` with title `"Kanidm Identity"` and icon `sh-kanidm`.

### Firewall

The module opens the TCP port extracted from `bindAddress` in `networking.firewall.allowedTCPPorts`.

### LoadCredential

Admin credentials are injected into the Kanidm systemd service via `LoadCredential`:

- `ADMIN_PASSWORD` ← `kanidm.adminPasswordFile`
- `IDM_ADMIN_PASSWORD` ← `kanidm.idmAdminPasswordFile`

These are referenced by the Kanidm provisioner at `services.kanidm.provision.adminPasswordFile` and `services.kanidm.provision.idmAdminPasswordFile`.

### Kanidm Package

The module pins a specific Kanidm package — `pkgs.kanidmWithSecretProvisioning_1_10` — which includes secret provisioning support.

## Secrets

### Cloudflare / ACME

The module auto-configures `security.acme` with Cloudflare DNS challenge credentials. The following sops secrets must be defined per-host:

- `CLOUDFLARE/EMAIL`
- `CLOUDFLARE/DNS_API_TOKEN`
- `CLOUDFLARE/ZONE_API_TOKEN`

The module reads their resolved paths via `config.sops.secrets."<name>".path`, so each host's sops configuration determines the actual filesystem location.

### Credential Files

| Option                        | Type  | Description                                                    |
| ----------------------------- | ----- | -------------------------------------------------------------- |
| `kanidm.adminPasswordFile`    | `str` | Path to the Kanidm admin password file (LoadCredential).       |
| `kanidm.idmAdminPasswordFile` | `str` | Path to the Kanidm IDM admin password file (LoadCredential).   |
| `kanidm.provisioningJsonFile` | `str` | Path to the Kanidm provisioning JSON with sensitive user data. |

## Operational Notes / Assumptions

- The ACME certificate group is set to `kanidm` so the Kanidm service can read the certificate files. The Kanidm systemd service has an ordering dependency on the ACME certificate service (`acme-${tlsCertificateDomain}.service`).
- Only port numbers from the bind address value are opened (e.g., `8443` from `[::]:8443`).
- OAuth2 clients and groups are declared declaratively via `server.identity.kanidm.oauth2` and `server.identity.kanidm.groups`.

## References

- [Kanidm Server Documentation](https://kanidm.github.io/kanidm/master/server.html)
- [Kanidm OAuth2 Integration](https://kanidm.github.io/kanidm/master/integrations/oauth2.html)
- [ACME / Let's Encrypt with Cloudflare DNS](https://nixos.wiki/wiki/ACME)
