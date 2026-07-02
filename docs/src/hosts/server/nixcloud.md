# nixcloud - Application Server

## Purpose

NixCloud is an application server hosting user-facing cloud services.
General purpose application server for replacing cloud services with self-hosted alternatives.

## Entry Point

- **Main file**: [`hosts/server/nixcloud/default.nix`](../../../../hosts/server/nixcloud/default.nix)

## Architecture / Services / Scope

### Application Workloads

| Workload       | Service        | File                                    | Domain            |
| -------------- | -------------- | --------------------------------------- | ----------------- |
| Home Assistant | home-assistant | `hosts/server/nixcloud/home-assistant/` | hassio.racci.dev  |
| Homebox        | homebox        | `hosts/server/nixcloud/homebox.nix`     | homebox.racci.dev |
| Immich         | immich         | `hosts/server/nixcloud/immich.nix`      | photos.racci.dev  |
| Music          | navidrome      | `hosts/server/nixcloud/music.nix`       | music.racci.dev   |
| Nextcloud      | nextcloud      | `hosts/server/nixcloud/nextcloud.nix`   | nc.racci.dev      |
| Search         | searx          | `hosts/server/nixcloud/search.nix`      | search.racci.dev  |

## Operational Notes / Assumptions

- All apps are exposed via the cluster's reverse proxy on the IO Coordinator.
- Applications using OAuth2/OIDC/SSO use the Identity Coordinator for authentication and authorization.
- Database services for these apps are provided by the cluster Database Coordinator via `server.database.postgres.*`.
- Media storage for Nextcloud and Immich uses seaweedfs mounts on the Storage Coordinator.

## References

- [Server Module](../../modules/nixos/server/default.md)
- [Identity Module](../../modules/nixos/server/identity.md)
- [Proxy Module](../../modules/nixos/server/proxy.md)
- [Identity Coordinator](../../hosts/server/nixauth.md)
- [Database Coordinator](../../hosts/server/nixdb.md)
- [Storage Coordinator](../../hosts/server/nixstor.md)
