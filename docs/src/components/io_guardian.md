# IO Guardian - Database Availability System

The IO Guardian system ensures that services across the infrastructure are aware
of the availability of centralized databases (PostgreSQL and Redis) hosted on `config.server.ioPrimaryHost`.
It provides graceful startup and shutdown coordination between the database host and dependent services on other servers.

## Overview

The system consists of two components:

1. **Guardian Server** (runs on client servers)

   - WebSocket server that listens for commands from the coordinator
   - Executes drain/undrain commands by controlling `io-databases.target`

1. **Guardian Client** (runs on the IO Host)

   - WebSocket client that connects to all guardian servers
   - Sends `undrain` command after databases are online (start dependent services)
   - Sends `drain` command before database shutdown (stop dependent services)

## How It Works

### System Startup

1. Client servers boot and run `wait-for-io-databases.service`
1. This service waits (with retries) until PostgreSQL and Redis on the IO Host are reachable
1. Once databases are confirmed available, the service completes
1. The `io-databases.target` is now ready to be activated
1. When the IO Hosts `io-database-coordinator.service` starts, it sends `undrain` to all clients
1. Clients start `io-databases.target`, which starts all dependent services

### Database Shutdown (Graceful Drain)

1. When `io-database-coordinator.service` stops (before databases stop)
1. It connects to all guardian servers via WebSocket
1. Sends `drain` command to each server
1. Guardian servers stop `io-databases.target`
1. Dependent services stop gracefully before databases go down

### Database Startup (Undrain)

1. When databases come online on the IO Host
1. `io-database-coordinator.service` starts
1. It sends `undrain` command to all guardian servers
1. Guardian servers start `io-databases.target`
1. All dependent services start

## Security

Communication is secured using a Pre-Shared Key (PSK) that must be at least 32
characters. All WebSocket connections must authenticate with this key before
commands are accepted.

### Generating the PSK

Generate a new PSK using OpenSSL:

```sh
openssl rand -base64 32
```

### Adding the Secret

Add the generated PSK to `hosts/server/secrets.yaml`:

```yaml
IO_GUARDIAN_PSK: <your-generated-key>
```

Then encrypt the file:

```sh
sops --encrypt --in-place hosts/server/secrets.yaml
```

## Configuration

### Port

The guardian WebSocket server listens on port **9876** by default. This port is
automatically opened to local subnets on servers with database dependencies.

### Dependent Services

Dependent Services will be automatically populated with service names where there
is a `systemd.service.<name>` defined from the names in `server.database.postgres`
or `server.database.redis`.

To manually add a service bind to the database availability target, add it to the
`server.database.dependentServices` option:

```nix
{
  server.database.dependentServices = [
    "my-service"
    "another-service"
  ];
}
```

Services listed here will:

- Start only when `io-databases.target` is active
- Stop when `io-databases.target` stops
- Restart when the target restarts

## Systemd Units

### On Client Servers

| Unit | Type | Description |
| --------------------------------- | ------- | ------------------------------------------------ |
| `io-guardian.service` | simple | WebSocket server for receiving commands |
| `io-databases.target` | target | Represents "databases are online" |
| `wait-for-io-databases.service`| oneshot | Waits for databases at boot (runs once) |

### On nixio

| Unit | Type | Description |
| ---------------------------------- | ------- | ------------------------------------------ |
| `io-database-coordinator.service` | oneshot | Sends undrain on start, drain on stop |

## Troubleshooting

### Checking Guardian Status

On client servers:

```sh
systemctl status io-guardian.service
systemctl status io-databases.target
systemctl status wait-for-io-databases.service
journalctl -u io-guardian.service -f
```

On IO Hosts:

```sh
systemctl status io-database-coordinator.service
journalctl -u io-database-coordinator.service
```

### Manual Commands

To manually start dependent services on a client:

```sh
systemctl start io-databases.target
```

To manually stop dependent services:

```sh
systemctl stop io-databases.target
```

### Common Issues

**Guardian server won't start:**

- Check that `IO_GUARDIAN_PSK` secret is properly configured
- Verify the sops decryption is working: `cat /run/secrets/IO_GUARDIAN_PSK`

**Services not starting after boot:**

- Check wait service
  logs: `journalctl -u wait-for-io-databases.service`
- Verify network connectivity to an IO Host on ports 5432 (Postgres) and 6379 (Redis)
- Ensure an IO Hosts coordinator has sent the undrain command

**Authentication failures in logs:**

- Ensure the same PSK is deployed to all servers
- Re-encrypt secrets if the key was changed

## Protocol Reference

The guardian uses a simple JSON-based WebSocket protocol:

### Authentication

```json
// Client sends:
{"type": "auth", "key": "<psk>"}

// Server responds:
{"type": "auth", "status": "ok", "message": "Authentication successful"}
// or
{"type": "auth", "status": "error", "message": "Invalid key"}
```

### Commands

```json
// Coordinator sends:
{"type": "command", "action": "drain"}
// or
{"type": "command", "action": "undrain"}
// or
{"type": "command", "action": "ping"}

// Server responds:
{"type": "response", "action": "<action>", "status": "ok", "message": "..."}
// or
{"type": "response", "action": "<action>", "status": "error", "message": "..."}
```
