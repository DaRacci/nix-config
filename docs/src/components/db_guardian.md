# DB Guardian - Database Availability System

## Purpose

The DB Guardian system ensures that services across the infrastructure are aware of the availability of centralised databases hosted on the Database Coordinator.
It provides graceful startup and shutdown coordination between the database host and dependent services on other servers.

## Entry Point

- **Main file**: [`modules/nixos/server/database/guardian.nix`](../../../modules/nixos/server/database/guardian.nix)

## Architecture / Services / Scope

The system consists of two components:

1. **Guardian Server** (runs on client servers)

   - WebSocket-over-TLS server that listens for commands from the coordinator
   - Requires a client certificate issued by the DB Guardian intermediate CA and only accepts the common names in `server.database.guardian.allowedClientCommonNames`
   - Runs as the unprivileged `db-guardian` user; a polkit rule grants it start and stop on `db-databases.target` only
   - Executes drain/undrain commands by controlling `db-databases.target`

1. **Guardian Client** (runs on the Database Coordinator)

   - WebSocket client that connects to all guardian servers over `wss://`
   - Verifies each guardian's certificate chain and hostname, and presents the single `db-guardian-coordinator` client certificate
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
1. If any client is unreachable, the coordinator fails and retries every 30 seconds until every client acknowledges the `undrain`

#### Database Shutdown (Graceful Drain)

1. When `db-database-coordinator.service` stops (before databases stop)
1. It connects to all guardian servers via WebSocket
1. Sends `drain` command to each server
1. Guardian servers stop `db-databases.target`
1. Dependent services stop gracefully before databases go down

`db-database-coordinator.service` is bound to PostgreSQL and Redis.
A database stop or restart therefore stops the coordinator and triggers the drain.
The coordinator is started again whenever either database starts, so a database restart cannot leave clients drained indefinitely.

#### Database Startup (Undrain)

1. When databases come online on the Database Coordinator
1. `db-database-coordinator.service` starts
1. It sends `undrain` command to all guardian servers
1. Guardian servers start `db-databases.target`
1. All dependent services start

If a guardian server is not reachable yet, the coordinator exits non-zero and systemd retries it every 30 seconds.
This closes the race where a client boots slower than the coordinator and would otherwise stay drained.

#### Reconciliation

While `db-database-coordinator.service` is active, `db-database-coordinator-reconcile.timer` re-sends `undrain` every 5 minutes.
The command is idempotent, so clients that are already undrained are unaffected.

This covers failures that happen after the initial undrain succeeded:

- A client boots while the databases are down, so its readiness check times out and its target fails. When the databases return, the next reconciliation starts the target again.
- A client's readiness check is restarted and fails, stopping the target. The next reconciliation starts it again.
- A client's target is stopped for any other reason while the coordinator is active.

The timer is started and stopped with the coordinator. An intentional drain stops the coordinator, which stops the timer, so reconciliation cannot undo the drain. If a reconciliation run fails, the timer retries at the next interval.

### Systemd Units

#### On Client Servers

| Unit | Type | Description |
| ------------------------------- | ------- | --------------------------------------------------- |
| `db-guardian.service` | simple | WebSocket server for receiving commands |
| `db-databases.target` | target | Represents "databases are online" |
| `wait-for-db-primary.service` | oneshot | Waits for the database primary host to be reachable |
| `wait-for-db-databases.service` | oneshot | Waits for databases at boot (runs once) |

The target is bound to `wait-for-db-databases.service` and is also wanted by it.
Restarting the readiness check therefore restarts the target instead of leaving it inactive.

#### On the Database Coordinator

| Unit | Type | Description |
| ------------------------------------------- | ------- | ------------------------------------------------------------------- |
| `db-database-coordinator.service` | oneshot | Sends undrain on start, drain on stop; retries failed undrains |
| `db-database-coordinator-reconcile.service` | oneshot | Re-sends undrain to all clients |
| `db-database-coordinator-reconcile.timer` | timer | Runs reconciliation every 5 minutes while the coordinator is active |

### Protocol Reference

The guardian uses a JSON-based WebSocket protocol over mutual TLS.
The TLS handshake authenticates both ends, so the first frame on a connection is a command:

**Commands**

Coordinator sends one of the supported actions (`drain`, `undrain`, or `ping`):

```json
{ "type": "command", "action": "drain" }
```

Server responds:

```json
{ "type": "response", "action": "<action>", "status": "ok", "message": "..." }
```

A client that sends any other message type receives an `error` response naming the type, and no command is executed.
That is how a stale client that still opens with an authentication frame is diagnosed.

## Secrets

Connections are mutually authenticated with TLS.
There is no shared secret in the protocol: the coordinator proves its identity with a client certificate, and the guardian proves its own with a per-host server certificate.
Both sides trust the **DB Guardian Intermediate CA** and nothing else, so a certificate issued by another service's intermediate is rejected during the handshake.

| Identity | Leaf profile | Issued to | Allowed by the guardian |
| ---------------------------- | ------------ | --------------------------------------------- | ----------------------- |
| `<host>` guardian server | `serverAuth` | Every guardian host, one leaf each | n/a |
| `db-guardian-coordinator` | `clientAuth` | The database primary host only | Common name allowlist |

The guardian rejects a connection whose client certificate common name is not in `server.database.guardian.allowedClientCommonNames`, and refuses to start at all when that list is empty.
An empty list is a Nix evaluation error, so a misconfigured generation cannot be built.

### Declared secrets

Certificate material is stored as binary SOPS files and passed to the units as systemd credentials.
No secret is a YAML value.

| Secret key | Owner | Group | Restart unit | Purpose |
| ---------------------------- | ----- | ----- | -------------------------------- | ------------------------------------------- |
| `db-guardian/CA_CERT` | root | root | `db-guardian.service` (clients), `db-database-coordinator.service` (coordinator) | Intermediate CA certificate used as the trust store |
| `db-guardian/SERVER_CERT` | root | root | `db-guardian.service` | Server leaf and intermediate chain |
| `db-guardian/SERVER_KEY` | root | root | `db-guardian.service` | Server leaf private key |
| `db-guardian/CLIENT_CERT` | root | root | `db-database-coordinator.service` | Coordinator leaf and intermediate chain |
| `db-guardian/CLIENT_KEY` | root | root | `db-database-coordinator.service` | Coordinator leaf private key |

The files live in `hosts/server/<host>/db-guardian-tls/` and are encrypted to that host's recipients only, so a guardian cannot decrypt another guardian's key.
Issue and rotate them with the procedure in [Internal mTLS CA](../security/internal_mtls_ca.md).

## Operational Notes / Assumptions

### Configuration

**Port**: The guardian WebSocket server listens on port **9876**. This port is automatically opened to local subnets on servers with database dependencies.
Port 9876 serves TLS only: the plaintext listener was removed in the same generation that introduced mutual TLS, and there is no transitional port.

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

- Check that the certificate secrets decrypted and are non-empty: `for f in /run/secrets/db-guardian/*; do test -s "$f" || echo "empty: $f"; done`
- Check that at least one client common name is configured: `systemctl show db-guardian.service -p ExecStart`
- A startup line `Refusing to start: at least one --allowed-cn is required` means the allowlist came through empty.

**Connections fail with a certificate error:**

- `certificate verify failed: unable to get local issuer certificate` on the guardian means the coordinator's chain does not reach the DB Guardian intermediate CA; confirm `CLIENT_CERT` carries the leaf followed by the intermediate.
- `Hostname mismatch` or `IP address mismatch` on the coordinator means the dialled name is missing from the guardian's server certificate; the SAN set must contain the bare hostname used in `--hosts`.
- `certificate has expired` means the leaf is past its validity; reissue it with the procedure in [Internal mTLS CA](../security/internal_mtls_ca.md).

**Guardian rejects the client with `certificate common name ... is not in the allowlist`:**

- The client certificate common name is not listed in `server.database.guardian.allowedClientCommonNames`; the observed name is in the log line.

**Services not starting after boot:**

- Check wait service logs: `journalctl -u wait-for-db-databases.service`
- Verify network connectivity to the Database Coordinator on ports 5432 (Postgres) and 6379 (Redis)
- Ensure the Database Coordinator has sent the undrain command
- Check the coordinator is active: `systemctl status db-database-coordinator.service`
- If the coordinator is inactive, start it: `systemctl start db-database-coordinator.service`

**Clients stay drained after a database restart:**

- Check the coordinator's last start and stop times: `systemctl show db-database-coordinator.service -p ActiveEnterTimestamp,InactiveEnterTimestamp,Result`
- Check for repeated undrain attempts: `journalctl -u db-database-coordinator.service`
- Check the reconciliation timer: `systemctl status db-database-coordinator-reconcile.timer`
- Check reconciliation runs: `journalctl -u db-database-coordinator-reconcile.service`
- The coordinator is restarted by `postgresql.service` and `redis.service`, retries failed undrains every 30 seconds, and re-asserts undrain every 5 minutes while active

**Drain or undrain fails with a polkit error:**

- `Access denied` or an `org.freedesktop.systemd1.manage-units` denial in `journalctl -u db-guardian.service` means the polkit rule did not match; confirm the daemon runs as `db-guardian` and that the request names `db-databases.target` with verb `start` or `stop`.
- `journalctl -u polkit` records the action, unit and verb the rule evaluated.

## References

- [Database Coordinator](../hosts/server/nixdb.md)
