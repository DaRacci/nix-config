# nixio - Ingress Host

## Purpose

NixIO serves as the cluster's primary ingress and network gateway.
It handles all external traffic routing, VPN tunnelling, DNS filtering, and dashboard aggregation for the server fleet.

## Entry Point

- **Main file**: [`hosts/server/nixio/default.nix`](../../../../hosts/server/nixio/default.nix)

## Architecture / Services / Scope

### Services

| Service              | Module / Path                      | Role                                                                  |
| -------------------- | ---------------------------------- | --------------------------------------------------------------------- |
| **Caddy**            | `hosts/server/nixio/proxy.nix`     | Reverse-proxy and TLS termination for all cluster services            |
| **Tailscale Tunnel** | `hosts/server/nixio/tunnel/`       | Mesh VPN connectivity, subnet routing, and ingress via Tailscale tags |
| **Dashy Dashboard**  | `hosts/server/nixio/dashboard.nix` | Aggregated service dashboard displayed on the IO Coordinator          |
| **AdGuard Home**     | `hosts/server/nixio/adguard.nix`   | Local DNS filtering and ad-blocking for the home network              |
| **Network Config**   | `default.nix`                      | Subnet declarations, IP forwarding (IPv4 + IPv6)                      |

## Secrets

### Declared secrets

| Secret key                  | Purpose                          |
| --------------------------- | -------------------------------- |
| `CLOUDFLARE/EMAIL`          | ACME DNS challenge account email |
| `CLOUDFLARE/ZONE_API_TOKEN` | ACME DNS challenge zone token    |
| `CLOUDFLARE/DNS_API_TOKEN`  | ACME DNS challenge API token     |

## Operational Notes / Assumptions

- This host is expected to have stable upstream network access plus reachability to the cluster LAN and tailnet, because ingress, DNS, and tunnel traffic all terminate here.
- Caddy terminates public TLS for cluster services, while some backends also use separate internal TLS or mTLS; certificate trust and backend server names must stay aligned with those upstream services.
- Reverse-proxied services remain individually responsible for their own authn/authz. Publishing a route here does not replace service-level access controls.

## References

- [Server Proxy Module](../../modules/nixos/server/proxy.md)
- [Tailscale Module](../../modules/nixos/services/tailscale.md)
- [Server Hosts Overview](overview.md)
- [Hosts Overview](../overview.md)
