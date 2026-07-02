# Server Database — Managed PostgreSQL and Redis

## Purpose

The database submodule provides a managed interface for PostgreSQL and Redis across the server infrastructure. It centralizes database configuration on the database primary host (`config.server.databasePrimaryHost`) while allowing client services to declaratively request databases. It automates provisioning of PostgreSQL databases and roles, management of Redis database IDs via static mappings, synchronization of service lifecycle with database availability using the [IO Guardian](../../components/io_guardian.md), and automated password handling via SOPS secrets.

## Entry Point

The module is implemented across several files in `modules/nixos/server/database/`:

- **Main file**: [default.nix](../../../../modules/nixos/server/database/default.nix): Core options and connection management.
- **Supporting file**: [postgres.nix](../../../../modules/nixos/server/database/postgres.nix): PostgreSQL-specific provisioning and secrets.
- **Supporting file**: [redis.nix](../../../../modules/nixos/server/database/redis.nix): Redis-specific ID mappings and security.
- **Supporting file**: [guardian.nix](../../../../modules/nixos/server/database/guardian.nix): Lifecycle synchronization and the [IO Guardian](../../../components/io_guardian.md).

#### Options

{{#include ../../../../generated/server-database-options.md}}
{{#include ../../../../generated/server-database-postgres-options.md}}
{{#include ../../../../generated/server-database-redis-options.md}}

## Architecture / Services / Scope

### Connection Management

The `server.database.host` option determines how services connect to databases. On the database primary host (`config.server.databasePrimaryHost`), it defaults to `localhost`. On all other hosts, it defaults to the value of `config.server.databasePrimaryHost`.

### PostgreSQL Management

When a service defines a database in `server.database.postgres`:

- **Automatic Provisioning**: The database primary host automatically creates the database and a role with the same name.
- **Password Management**: A SOPS secret is expected at `POSTGRES/<DB_NAME_UPPER>_PASSWORD`. Database names containing hyphens (`-`) replace them with underscores (`_`) when constructing the secret path. The system automatically sets this password for the role during the `postgresql-setup` service.
- **Aggregated Configuration**: The database primary host collects all PostgreSQL requirements from across the entire flake to ensure all necessary extensions and initial scripts are loaded.

### Redis Management

Redis management uses a similar aggregation pattern:

- **Database IDs**: Because Redis uses numeric IDs (0-15), the system uses a static mapping file (`redis-mappings.json`) on the database primary host to ensure consistent ID assignment across the fleet.
- **Password Management**: A shared password for the primary Redis instance is managed via `REDIS/PASSWORD` in SOPS.
- **Tooling**: Use the `update-redis-mappings` command on the database primary host to update the mapping file when adding new Redis clients.

### IO Guardian Coordination

Lifecycle management is handled by the [IO Guardian](../../../components/io_guardian.md). A pre-shared key for guardian communication is managed via the `DB_GUARDIAN_PSK` SOPS secret.

- **On Clients**: Services that use these database modules are automatically bound to `db-databases.target`. This ensures they only start when the remote databases are reachable and stop before the databases go offline.
- **On Database Primary Host**: The `db-database-coordinator` service manages the `drain` and `undrain` signals sent to clients during system startup and shutdown.

## Secrets

- `POSTGRES/<DB_NAME_UPPER>_PASSWORD`: Per-database role password, provisioned during `postgresql-setup`.
- `REDIS/PASSWORD`: Shared password for the primary Redis instance.
- `DB_GUARDIAN_PSK`: Pre-shared key for IO Guardian communication.

## Operational Notes / Assumptions

- The host designated as the database primary host (`config.server.databasePrimaryHost`) is responsible for running the actual database engines. It aggregates all database requirements from every host in the flake and applies them locally.
- Client services request databases by declaring entries in `server.database.postgres` or `server.database.redis`; the submodule wires up connection info, secrets, and lifecycle binding.

## References

- [IO Guardian](../../components/io_guardian.md)
