# Database Submodule

The database submodule provides a managed interface for PostgreSQL and Redis across the server infrastructure. It centralizes database configuration on the primary database host (`config.server.ioPrimaryHost`) while allowing client services to declaratively request databases.

The module is implemented across several files in `modules/nixos/server/database/`:

- `default.nix`: Core options and connection management.
- `postgres.nix`: PostgreSQL-specific provisioning and secrets.
- `redis.nix`: Redis-specific ID mappings and security.
- `guardian.nix`: Lifecycle synchronization and the [IO Guardian](../../../components/io_guardian.md).

## Purpose

This submodule automates:

- Provisioning of PostgreSQL databases and roles.
- Management of Redis database IDs via static mappings.
- Synchronization of service lifecycle with database availability using the [IO Guardian](../../../components/io_guardian.md).
- Automated password handling via SOPS secrets.

## Entry Points

- `server.database.postgres`: Manage PostgreSQL databases and users (in `postgres.nix`).
- `server.database.redis`: Manage Redis database instances (in `redis.nix`).
- `server.database.host`: Centralized host address for database connections (in `default.nix`).
- `server.database.dependentServices`: Lifecycle coordination for dependent services (in `guardian.nix`).

## Key Options and Behaviors

### Connection Management

The `server.database.host` option determines how services connect to databases. On the primary database host (`ioPrimaryHost`), it defaults to `localhost`. On all other hosts, it defaults to the value of `config.server.ioPrimaryHost`.

### PostgreSQL Management

When a service defines a database in `server.database.postgres`:

- **Automatic Provisioning**: The IO Host automatically creates the database and a role with the same name.
- **Password Management**: A SOPS secret is expected at `POSTGRES/<DB_NAME_UPPER>_PASSWORD`. Database names containing hyphens (`-`) replace them with underscores (`_`) when constructing the secret path. The system automatically sets this password for the role during the `postgresql-setup` service.
- **Aggregated Configuration**: The IO Host collects all PostgreSQL requirements from across the entire flake to ensure all necessary extensions and initial scripts are loaded.

### Redis Management

Redis management uses a similar aggregation pattern:

- **Database IDs**: Because Redis uses numeric IDs (0-15), the system uses a static mapping file (`redis-mappings.json`) on the IO Host to ensure consistent ID assignment across the fleet.
- **Password Management**: A shared password for the primary Redis instance is managed via `REDIS/PASSWORD` in SOPS.
- **Tooling**: Use the `update-redis-mappings` command on the IO Host to update the mapping file when adding new Redis clients.

## Per-Module Examples

### Connection Configuration (`default.nix`)

You can override the default database host (e.g., if using a custom tunnel or local proxy):

```nix
{
  server.database.host = "10.0.0.50";
}
```

### PostgreSQL Example (`postgres.nix`)

Requesting a PostgreSQL database for a service:

```nix
{
  server.database.postgres."my-app" = {
    # database and user will be 'my-app'
    # Password expected at sops secret: POSTGRES/MY_APP_PASSWORD
  };
}
```

### Redis Example (`redis.nix`)

Requesting a Redis database:

```nix
{
  server.database.redis.myapp = {
    # prefix will be 'myapp'
    # database_id is assigned from redis-mappings.json
  };
}
```

### Guardian Dependency Example (`guardian.nix`)

Manually adding services to the database lifecycle coordination:

```nix
{
  server.database.dependentServices = [
    "custom-backend.service"
    "worker-node" # .service suffix is added automatically
  ];
}
```

## Operational Notes

### IO Guardian Coordination

Lifecycle management is handled by the [IO Guardian](../../../components/io_guardian.md).

- **On Clients**: Services that use these database modules are automatically bound to `io-databases.target`. This ensures they only start when the remote databases are reachable and stop before the databases go offline.
- **On IO Primary Host**: The `io-database-coordinator` service manages the `drain` and `undrain` signals sent to clients during system startup and shutdown.

### IO Primary Host Behavior

The host designated as the IO Primary Host (`config.server.ioPrimaryHost`) is responsible for running the actual database engines. It aggregates all database requirements from every host in the flake and applies them locally.
