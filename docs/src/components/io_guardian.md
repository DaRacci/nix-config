# IO Guardian - Database Availability System

## Purpose

The IO Guardian system ensures that services across the infrastructure are aware of the availability of centralized databases hosted on the Database Coordinator.
It provides graceful startup and shutdown coordination between the database host and dependent services on other servers.

## Entry Point

- **Main file**: [`modules/nixos/server/database/guardian.nix`](../../../modules/nixos/server/database/guardian.nix)

## Architecture / Services / Scope

The system consists of two components:

1. **Guardian Server** (runs on client servers)
   - WebSocket server that listens for commands from the coordinator
   - Secures connections with a pre-shared key (PSK) from the `DB_GUARDIAN_PSK` secret
   - Executes drain/undrain commands by controlling `db-databases.target`

1. **Guardian Client** (runs on the Database Coordinator)
   - WebSocket client that connects to all guardian servers
   - Sends `undrain` command after databases are online (start dependent services)
   - Sends `drain` command before database shutdown (stop dependent services)

### How It Works

#### System Startup

1. Client servers boot and run `wait-for-db-databases.service`
1. This service waits (with retries) until PostgreSQL and Redis on the Database Coordinator are reachable
1. Once databases are confirmed available, the service completes
1. The `db-databases.target` is now ready to be activated
1. When the Database Coordinator's `db-database-coordinator.service` starts, it sends `undrain` to all clients
1. Clients start `db-databases.target`, which starts all dependent services

#### Database Shutdown (Graceful Drain)

1. When `db-database-coordinator.service` stops (before databases stop)
1. It connects to all guardian servers via WebSocket
1. Sends `drain` command to each server
1. Guardian servers stop `db-databases.target`
1. Dependent services stop gracefully before databases go down

#### Database Startup (Undrain)

1. When databases come online on the Database Coordinator
1. `db-database-coordinator.service` starts
1. It sends `undrain` command to all guardian servers
1. Guardian servers start `db-databases.target`
1. All dependent services start

### Systemd Units

#### On Client Servers

| Unit                            | Type    | Description                             |
| ------------------------------- | ------- | --------------------------------------- |
| `db-guardian.service`           | simple  | WebSocket server for receiving commands |
| `db-databases.target`           | target  | Represents "databases are online"       |
| `wait-for-db-databases.service` | oneshot | Waits for databases at boot (runs once) |

#### On the Database Coordinator

| Unit                              | Type    | Description                           |
| --------------------------------- | ------- | ------------------------------------- |
| `db-database-coordinator.service` | oneshot | Sends undrain on start, drain on stop |

### Protocol Reference

The guardian uses a simple JSON-based WebSocket protocol:

**Authentication**

Client sends:

```json
{ "type": "auth", "key": "<psk>" }
```

Server responds:

```json
{ "type": "auth", "status": "ok", "message": "Authentication successful" }
```

**Commands**

Coordinator sends one of the supported actions (`drain`, `undrain`, or `ping`):

```json
{ "type": "command", "action": "drain" }
```

Server responds:

```json
{ "type": "response", "action": "<action>", "status": "ok", "message": "..." }
```

## Secrets

Communication is secured using a Pre-Shared Key (PSK) that must be at least 32 characters.
All WebSocket connections must authenticate with this key before commands are accepted.

### Declared secrets

| Secret key        | Owner | Group | Restart unit        | Purpose                                |
| ----------------- | ----- | ----- | ------------------- | -------------------------------------- |
| `DB_GUARDIAN_PSK` | root  | root  | db-guardian.service | Authenticate DB Guardian WebSocket API |

## Operational Notes / Assumptions

### Configuration

**Port**: The guardian WebSocket server listens on port **9876** by default. This port is automatically opened to local subnets on servers with database dependencies.

**Dependent Services**: Dependent Services will be automatically populated with service names where there is a `systemd.service.<name>` defined from the names in `server.database.postgres` or `server.database.redis`.
To manually add a service bind to the database availability target, add it to the `server.database.dependentServices` option.
Services listed here will start only when `db-databases.target` is active, stop when it stops, and restart when the target restarts.

### Troubleshooting

#### Checking Guardian Status

On client servers:

```sh
systemctl status db-guardian.service
systemctl status db-databases.target
systemctl status wait-for-db-databases.service
journalctl -u db-guardian.service -f
```

On the Database Coordinator:

```sh
systemctl status db-database-coordinator.service
journalctl -u db-database-coordinator.service
```

#### Manual Commands

To manually start/stop dependent services on a client:

```sh
systemctl start db-databases.target
systemctl stop db-databases.target
```

#### Common Issues

**Guardian server won't start:**

- Check that `DB_GUARDIAN_PSK` secret is properly configured
- Verify the SOPS decryption is working and the secret is non-empty: `test -s /run/secrets/DB_GUARDIAN_PSK`

**Services not starting after boot:**

- Check wait service logs: `journalctl -u wait-for-db-databases.service`
- Verify network connectivity to the Database Coordinator on ports 5432 (Postgres) and 6379 (Redis)
- Ensure the Database Coordinator has sent the undrain command

**Authentication failures in logs:**

- Ensure the same PSK is deployed to all servers
- Re-encrypt secrets if the key was changed

## References

- [Database Coordinator](../hosts/server/nixdb.md)
