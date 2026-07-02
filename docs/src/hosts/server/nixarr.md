# nixarr — Media Management

## Purpose

`nixarr` is the media management host for the fleet.
All downloading happens through a VPN tunnel so P2P traffic is isolated.

## Entry Point

- **Main file**: [`hosts/server/nixarr/default.nix`](../../../../hosts/server/nixarr/default.nix)

## Architecture / Services / Scope

### Playback

- **Jellyfin**: Media server with hardware-accelerated transcoding (VA-API via `/dev/dri/renderD128`), hardware encoding for HEVC and hardware decoding for AV1/H.264/HEVC/VP9.

### Media Management ("arr" stack)

| App          | Role                                         |
| ------------ | -------------------------------------------- |
| Radarr       | Movie management                             |
| Sonarr       | TV series management                         |
| Prowlarr     | Indexer management for the whole stack       |
| Lidarr       | Music management                             |
| Readarr      | Book management                              |
| Bazarr       | Subtitle management                          |
| Transmission | BitTorrent downloader (Flood UI, cross-seed) |
| Sabnzbd      | Usenet downloader                            |
| Seerr        | User-facing media request portal             |

### Networking / VPN

- All downloading apps run inside a WireGuard VPN namespace (`vpnNamespaces.wg`) so P2P/usenet traffic egresses through the VPN rather than the host's normal connection.
- The VPN config is provided as a sops binary secret (`wg.conf`) that restarts `wg.service` when rotated.
- Access to VPN-isolated apps is allowed from the LAN and the configured tailnet; see the [Tailscale module documentation](../../modules/nixos/services/tailscale.md) for the cluster's tailnet integration.

### Authentication

- An `arr-services` Kanidm OAuth2 context restricts the media apps to the `sysadmin` group on the Identity Coordinator.

## Secrets

### Declared secrets

| Secret key        | Purpose                                  |
| ----------------- | ---------------------------------------- |
| `wireguard`       | WireGuard VPN config (binary, `wg.conf`) |
| `SSH_PRIVATE_KEY` | SSH key used for cluster coordination    |

## Operational Notes / Assumptions

- VPN download services restart on failure and wait for `wg.service` to come up before starting, so they don't fail during early boot when networking isn't ready.
- Hardware transcoding relies on the host exposing a working `/dev/dri` device.
- Media apps are exposed through the IO Coordinator reverse proxy.

## References

- [nixarr](https://github.com/rasmus-kirk/nixarr/)
- [Identity Coordinator](../../hosts/server/nixauth.md)
- [IO Coordinator](../../hosts/server/nixio.md)
