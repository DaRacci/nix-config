# NixCloud - Application Server

## Purpose

NixCloud is an application server hosting user-facing cloud services.
General purpose application server for replacing cloud services with self-hosted alternatives.

## Entry Point

- **Main file**: [`hosts/server/nixcloud/default.nix`](../../../../hosts/server/nixcloud/default.nix)

## Architecture / Services / Scope

### Application Workloads

| Workload | Service | File | Domain |
| -------------- | ---------------- | --------------------------------------- | ------------------- |
| Home Assistant | `home-assistant` | `hosts/server/nixcloud/home-assistant/` | `hassio.racci.dev` |
| Homebox | `homebox` | `hosts/server/nixcloud/homebox.nix` | `homebox.racci.dev` |
| Immich | `immich` | `hosts/server/nixcloud/immich.nix` | `photos.racci.dev` |
| Music | `navidrome` | `hosts/server/nixcloud/music.nix` | `music.racci.dev` |
| Nextcloud | `nextcloud` | `hosts/server/nixcloud/nextcloud.nix` | `nc.racci.dev` |
| Search | `searx` | `hosts/server/nixcloud/search.nix` | `search.racci.dev` |

### MQTT Broker

- `mosquitto` listens on TCP 1883 and is exposed as `mqtt.racci.dev` through the IO Coordinator's L4 proxy.
- System metrics are published under `$SYS/#`; anonymous access is disabled.
- Accounts and ACLs are declared in `hosts/server/nixcloud/home-assistant/connectivity.nix`.
  The `uptimekuma` account is read-only on `$SYS/broker/uptime`, `zigbee2mqtt/bridge/state`, and `homeassistant/status`.

## Operational Notes / Assumptions

- All apps are exposed via the cluster's reverse proxy on the IO Coordinator.
- Applications using OAuth2/OIDC/SSO use the Identity Coordinator for authentication and authorisation.
- Database services for these apps are provided by the cluster Database Coordinator via `server.database.postgres.*`.
- Media storage for Nextcloud and Immich uses SeaweedFS mounts on the Storage Coordinator.
- Nextcloud has no declarative admin account: nixpkgs removed the `adminuser`/`adminpassFile` options.
  Create the admin after installation with `nextcloud-occ user:add <username>` followed by `nextcloud-occ group:adduser admin <username>`.

## References

- [Server Module](../../modules/nixos/server/default.md)
- [Proxy Module](../../modules/nixos/server/proxy.md)
