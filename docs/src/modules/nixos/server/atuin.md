# Atuin — Shell History Sync

## Purpose

Wraps the upstream `services.atuin` module with the repository's PostgreSQL, SOPS, and reverse proxy conventions.
The module is inactive unless a host enables it.

## Entry Point

- **Main file**: [atuin.nix](../../../../../modules/nixos/server/atuin.nix)

## Architecture / Services / Scope

When `services.atuin.enable` is set:

- **Database**: Declares `server.database.postgres.atuin`, backed by the Database Coordinator.
- **Credentials**: Renders `ATUIN_DB_URI` into the `ATUIN_ENV` SOPS template and passes it through `environmentFile`.
- **Proxy**: Exposes `atuin.racci.dev` publicly through the IO Coordinator and forwards to the sync server.

## Operational Notes / Assumptions

- Consumption is per-host: set `services.atuin.enable = true` on the host that should run the server.
- The server listens on `0.0.0.0` so the IO Coordinator can reach it over the backend network.
- `database.createLocally = false` avoids local PostgreSQL setup.
  Atuin connects to PostgreSQL on the Database Coordinator using `ATUIN_DB_URI`.
- Open registration is enabled to allow the initial account creation; disable it once the required accounts exist.

## References

- [Atuin](https://atuin.sh)
- [NixDev](../../../hosts/server/nixdev.md)
