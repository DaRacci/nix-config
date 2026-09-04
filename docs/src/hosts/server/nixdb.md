# nixdb - Database & Administration

## Purpose

NixDB is the dedicated database host for the server fleet.
It owns all databases and their administrative tools.

This host coordinates with the [IO Guardian](../../components/io_guardian.md) to ensure that all database-dependent services on other servers start only after the databases are reachable, and stop gracefully before the databases go offline.

## Entry Point

- **Main file**: [`hosts/server/nixdb/default.nix`](../../../../hosts/server/nixdb/default.nix)
- **Supporting file**: [`hosts/server/nixdb/redis-mappings.json`](../../../../hosts/server/nixdb/redis-mappings.json)

## Architecture / Services / Scope

| Service            | Module                      | Notes                                                        |
| ------------------ | --------------------------- | ------------------------------------------------------------ |
| PostgreSQL         | `database/postgres.nix`     | Primary Postgres instance; TCP on subnet CIDRs               |
| pgAdmin            | Host-level config           | Served behind Caddy reverse proxy on `nixio`                 |
| Redis              | `database/redis.nix`        | Redis instances, mappings from `redis-mappings.json`         |
| PostgreSQL backups | `services.postgresqlBackup` | Daily zstd dumps                                             |
| DB guardian        | `database/guardian.nix`     | Coordinates startup/shutdown ordering for DB-dependent hosts |

### PostgreSQL

PostgreSQL is configured with JIT and the system_stats extension.
Authentication uses `scram-sha-256` for all network connections from `server.network.subnets`, and `peer`/`trust`/`scram-sha-256` for local socket connections.

### Redis

The module reads `redis-mappings.json` from `hosts/server/${config.server.databasePrimaryHost}/redis-mappings.json`.

### PostgreSQL Backups

Backups are enabled with:

- Compression: `zstd` at level 12
- Location: `/var/lib/postgresql/backup`
- Databases: Automatically derived from `services.postgresql.ensureDatabases`

## Secrets

### Declared secrets

| Secret key                   | Purpose              |
| ---------------------------- | -------------------- |
| `PGADMIN_PASSWORD`           | pgAdmin web login    |
| `POSTGRES/POSTGRES_PASSWORD` | PostgreSQL superuser |

### Dynamic secrets: `fromAllServers`

The host file defines a `fromAllServers` helper that collects secrets from every other server configuration in the flake.
This is used to discover all `POSTGRES/*_PASSWORD` secrets from other servers' sops declarations and re-declare them on the Database Coordinator with:

- Owner/group remapped to `postgres` user/group
- `restartUnits` set to `postgresql.service`

This is the mechanism that lets PostgreSQL authenticate users from every server, each server declares its own DB password secret, and `nixdb` picks them all up centrally.
All postgres secrets MUST be declared both in the source host's `sopsFile` and in the Database Coordinator's own `secrets.yaml`.

### Redis mappings

`redis-mappings.json` is stored in the host's directory and read by the Redis module. It maps Redis database indices to application names.

## Operational Notes / Assumptions

- **Backup path choice**: Backups go to `/var/lib/postgresql/backup`. Ensure sufficient disk space for daily zstd-compressed dumps.
- **Firewall scope**: Only PostgreSQL TCP port is opened in `allowedTCPPorts`. Redis and guardian communication rely on internal network access.

## References

- [Database Module](../../modules/nixos/server/database.md) — module architecture and options
- [IO Guardian](../../components/io_guardian.md) — startup coordination / guardian details
- [IO Coordinator](../../hosts/server/nixio.md)
