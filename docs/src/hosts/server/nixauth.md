# nixauth - Identity Management

## Purpose

NixAuth is the identity provider host.
It owns the identity role for the server fleet, managing SSO, OAuth2 client registration, provisioning, and user authentication.

## Entry Point

- **Main file**: [`hosts/server/nixauth/default.nix`](../../../../hosts/server/nixauth/default.nix)

The host file is a thin declarative wrapper over `server.identity.*`.
Including provisioning JSON and OAuth2 client definitions.

## Secrets

### Declared secrets

| Secret key                      | Purpose                                    |
| ------------------------------- | ------------------------------------------ |
| `CLOUDFLARE/EMAIL`              | ACME DNS challenge account email           |
| `CLOUDFLARE/ZONE_API_TOKEN`     | ACME DNS challenge zone token              |
| `CLOUDFLARE/DNS_API_TOKEN`      | ACME DNS challenge API token               |
| `KANIDM/ADMIN_PASSWORD`         | Kanidm admin user password                 |
| `KANIDM/IDM_ADMIN_PASSWORD`     | Kanidm IDM admin password                  |
| `KANIDM/PROVISIONING_JSON`      | Provisioning JSON with sensitive user data |
| `KANIDM/OAUTH2/<CLIENT>_SECRET` | Per-client OAuth2 basic secret             |

### `KANIDM/PROVISIONING_JSON` details

The provisioning JSON has its own encrypted [file](../../../../hosts/server/nixauth/provisioning.json), this includes user data which shouldn't be publicly visible.

### OAuth2 secrets auto-generation

For every non-public OAuth2 client in `server.identity.kanidm.oauth2`, the host file auto-generates a corresponding SOPS secret path:

```nix
"KANIDM/OAUTH2/${toUpper clientId}_SECRET"
```

For example, `oauth2.nextcloud` produces the secret key `KANIDM/OAUTH2/NEXTCLOUD_SECRET`.

## Operational Notes / Assumptions

### Cloudflare / ACME

The identity module configures `security.acme` with Cloudflare DNS challenge using the three `CLOUDFLARE/*` secrets listed above.
The ACME certificate domain defaults to `auth.racci.dev` and the certificate group is set to `kanidm` so the Kanidm service can read & serve its certs.

## References

- [Kanidm Server Documentation](https://kanidm.github.io/kanidm/master/server.html)
- [ACME / Let's Encrypt with Cloudflare DNS](https://nixos.wiki/wiki/ACME)
