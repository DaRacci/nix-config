# DB Guardian Mutual TLS

Replace DB Guardian's plaintext WebSocket transport and shared pre-shared key with mutual TLS, and run the guardian daemon as an unprivileged user whose only systemd capability is starting and stopping `db-databases.target`.

## Why

The guardian coordinates database availability across every host that declares a database dependency. Three properties of its current implementation do not match the trust it is given:

- **The transport is plaintext on a flat LAN.** `db-guardian.service` binds `0.0.0.0:9876` (`modules/nixos/server/database/guardian.nix:140`) and `client.py:76` dials `ws://{host}:{port}`. Every drain/undrain command, and the credential that authorises it, crosses the local subnet in the clear. Any host on that subnet can read the credential and can answer as a guardian.
- **A single static secret authenticates both directions.** `DB_GUARDIAN_PSK` is one 32+ character string, stored once in `hosts/server/secrets.yaml`, read by every guardian and by the coordinator, and sent verbatim in the first frame every five minutes by the reconciliation timer (`client.py:82`, `db-database-coordinator-reconcile.timer`). It is long-lived, non-rotating, unscoped, and identical on three hosts.
- **The client never authenticates the server.** `websockets.connect(uri)` with no `ssl` argument accepts any peer that answers on the port. A host that can reach the port can impersonate a guardian and answer `undrain` while the real guardian is drained, or answer `drain` to stop dependent services during normal operation.
- **The daemon parses network JSON as root.** `server.py` runs with no `User=` (so `root`) explicitly to be able to call systemd, and the module comment at `guardian.nix:145` says so. Its only hardening is five directives (`ProtectHome`, `PrivateTmp`, `PrivateDevices`, `ProtectKernelTunables`, `ProtectKernelModules`). A JSON parser and a TLS-adjacent network loop running as root, on three hosts, for the privilege of two `systemctl` calls.

The blast radius is asymmetric: a compromised guardian can stop services, but a compromised coordinator credential can stop services on every host that depends on the database.

## What Changes

### Mutual TLS on the guardian listener

The guardian server terminates TLS itself with `ssl.PROTOCOL_TLS_SERVER`, `minimum_version = TLSv1_2`, `verify_mode = CERT_REQUIRED`, `load_cert_chain`, and `load_verify_locations`, following the shape already proven in `pkgs/alloy-dynamic-capture/api.py`. Every connection must present a client certificate before a single application frame is read.

The coordinator client builds its context with `ssl.create_default_context(cafile=…)` and `load_cert_chain(…)`, following `pkgs/alloy-dynamic-capture/relay.py`. That context is left at its defaults — `CERT_REQUIRED` and `check_hostname` — so the coordinator verifies the guardian's identity and the hostname it dialled. There is no flag to disable verification.

### A dedicated DB Guardian CA, not the monitoring CA

A new `DB Guardian Intermediate CA` is added under the existing offline `Fleet mTLS Root CA` described in `docs/src/security/internal_mtls_ca.md`. It signs only guardian leaves. The Alloy monitoring intermediate stays untouched.

This is not cosmetic. Guardian authorization is decided by the client certificate's common name, so if guardian leaves and monitoring leaves shared an intermediate, the holder of the monitoring intermediate key could mint a certificate carrying the guardian's common name and pass the allowlist. Splitting the intermediate makes "can drive the guardian" a property of a key that the monitoring relay never holds.

### Per-host server certificates, one coordinator identity

Each guardian host gets a `serverAuth` leaf whose SANs contain the hostname the coordinator actually dials. One client identity — CN `db-guardian-coordinator` — is deployed to whichever host is the database primary, and every guardian's allowlist contains exactly that name.

### The PSK is deleted, not deprecated

`DB_GUARDIAN_PSK` is removed from `hosts/server/secrets.yaml`, the `sops.secrets` declaration, all three `LoadCredential` lines, both `--psk-file` arguments, `load_psk()` in both Python files, the `{"type":"auth"}` frame, and its handler branch. The `provided_key == psk` comparison at `server.py:253` disappears with the branch that contains it rather than being rewritten as a constant-time compare: once identity comes from the TLS layer there is no secret left to compare, and a `hmac.compare_digest` against a constant would be dead code that suggests a control exists where none does.

### The daemon drops root

`db-guardian.service` runs as a dedicated static system user `db-guardian`. A polkit rule grants that user exactly `org.freedesktop.systemd1.manage-units` for `unit == "db-databases.target"` with `verb` in `start`/`stop` — the same shape as the decky-loader rule in `modules/nixos/core/gaming.nix:149`. Everything else the daemon does becomes readable-only D-Bus, which unprivileged users already have. Hardening gains `ProtectSystem`, `NoNewPrivileges`, an empty `CapabilityBoundingSet`, and a `SystemCallFilter`.

### Documentation ships with the code

`docs/src/components/db_guardian.md` and `docs/src/modules/nixos/server/database.md` are updated in the same commit as the generation that changes the behaviour, per `AGENTS.md`. `docs/src/security/internal_mtls_ca.md` gains the guardian intermediate in the trust hierarchy and the consumer table.

## Capabilities

### New capabilities

#### capability: db-guardian-security

The DB Guardian transport SHALL be mutually authenticated TLS, SHALL refuse to start without a non-empty client common-name allowlist, SHALL carry no shared static secret, and SHALL run as an unprivileged identity limited to starting and stopping the database availability target.

- **WHEN** a coordinator connects to a guardian
- **THEN** the connection SHALL be TLS 1.2 or later with a client certificate verified against the Fleet mTLS root before any application frame is read
- **AND** the guardian SHALL reject the connection if the client certificate's common name is not in its configured allowlist

- **WHEN** the coordinator connects to a guardian
- **THEN** it SHALL verify the guardian's certificate chain and hostname against the Fleet mTLS root, with no option to skip verification

- **WHEN** the guardian starts with an empty client allowlist
- **THEN** it SHALL exit non-zero instead of listening

- **WHEN** a drain or undrain command is processed
- **THEN** it SHALL be executed by a non-root user via polkit limited to `org.freedesktop.systemd1.manage-units` on `db-databases.target` for the `start` and `stop` verbs

### Unchanged capabilities

No `db-guardian` capability spec exists yet; this change creates `db-guardian-security` as the first one. Nothing in `openspec/specs/` describes the guardian, so no existing spec needs modification.

## Non-goals

- **Changing what drain and undrain mean.** The target, the command vocabulary, the 5-minute reconciliation, the 30-second coordinator retry, and the `--fail-fast` behaviour on undrain are unchanged. This change moves the transport and the privilege boundary only.
- **Creating or reallocating hosts.** Moving the coordinator to `nixdb` is the business of `openspec/changes/reallocate-server-service-roles`, which is active and incomplete. This change adds no host and renames no unit, and it neither waits for nor blocks that change; host placement is derived (see below).
- **Changing the monitoring CA or its consumers.** The Alloy intermediate, its leaves, and `allowedClientCommonNames` in `hosts/server/shared/default.nix` are not touched.
- **Certificate revocation.** Consistent with the existing internal CA documentation, no CRL or OCSP checking is introduced. Compromise is handled by rotating the guardian intermediate.
- **Rotating the existing PSK before removal.** It is deleted, not rotated.
- **General-purpose service hardening across the fleet.** Only `db-guardian.service` gains directives.
- **Extending the guardian protocol.** No new actions, no command signing, no message-level authentication.

## Impact

### Code

- `pkgs/db-guardian/server.py` — TLS listener, peer-certificate extraction, startup allowlist assertion, removal of PSK loading and the auth branch, `run_tests()` cases for the new refusals
- `pkgs/db-guardian/client.py` — TLS context, hostname verification, removal of PSK loading and the auth frame
- `pkgs/db-guardian/default.nix` — version bump; no dependency change (both sides already depend on `websockets` and its bundled `ssl` usage)
- `modules/nixos/server/database/guardian.nix` — sops declarations, `LoadCredential` replacement, `User`/`Group`, polkit rule, hardening, removal of the four `DB_GUARDIAN_PSK` references

### Hosts

- Guardian hosts — currently `nixcloud`, `nixdev`, `nixserv` (those declaring `server.database.postgres` or `server.database.redis`): new server certificate and key secrets, new `db-guardian` user, service restarted
- Database primary — whichever host `isThisIOPrimaryHost` selects today (`nixio`), or `isThisPrimaryHost config.server.databasePrimaryHost` after `reallocate-server-service-roles` lands (`nixdb`): new client certificate and key secrets, coordinator and reconcile units restarted
- No host is added, removed, or renamed by this change.

### Secrets

- Added, per host, as binary sops files: `hosts/server/<host>/db-guardian-tls/CA_CERT`, `SERVER_CERT`, `SERVER_KEY`, and on the database primary `CLIENT_CERT`, `CLIENT_KEY`
- Removed: `DB_GUARDIAN_PSK` from `hosts/server/secrets.yaml`
- No new `.sops.yaml` creation rule: the per-host `path_regex: hosts/server/<host>/` rules already cover the new directories. Creating `nixdb` requires its own host rule, which is `reallocate-server-service-roles`' responsibility; if that host exists by the time this change is deployed, the rule is a prerequisite of encrypting to it, not of this change's design.

### Downtime

No database downtime, and no change to drain or undrain semantics. The cutover is one window containing two generations:

- **Generation A — certificates.** New sops secrets, `LoadCredential` entries, and the `db-guardian` user. Nothing reads them; the guardian still listens in plaintext with the PSK and the coordinator still dials `ws://`. Behaviour is identical to today.
- **Generation B — cutover.** The guardian listener becomes TLS-only on `9876`, the plaintext listener, the PSK and the auth frame are deleted, and the coordinator dials `wss://`.

Both generations are deployed to every host inside the same window. There is no transitional port, no dual-protocol listener, and no compatibility shim at any point, and no host ever runs a protocol its peer does not speak.

**What the window costs.** Because the protocol change is all-or-nothing per host, the guardian control plane is unusable from the moment the first host is switched until the new coordinator on the database primary has completed its first undrain sweep. Specifically:

- **Drain and undrain are unavailable for the duration of the window.** If the database stops in that interval, dependent services on the guardians keep running against a database that is down. That is an unplanned-outage exposure, not a planned one: the window is chosen while the database is up, and nothing in the window itself stops it.
- **The operator MUST sequence the hosts so the database primary is last.** Switch the guardian hosts (`nixcloud`, `nixdev`, `nixserv`) first while the database is up, so nothing needs draining during their rebuilds; switch the database primary last. The primary's switch restarts only `db-database-coordinator.service` and `db-database-coordinator-reconcile.service` and must not restart PostgreSQL — PostgreSQL's unit inputs do not change, and a `nixos-rebuild dry-activate` pre-check on the primary confirms `postgresql.service` is absent from the restart list before the window opens. By then every guardian already speaks TLS-only, and the new coordinator's reconcile timer undrains every guardian within one interval (5 minutes).
- **Do not stop or restart PostgreSQL on the database primary between the first guardian switch and the completion of the coordinator's first undrain sweep.** If it happens for an unplanned reason, dependent services stay up until the sweep succeeds; there is no second path by which the guardians can be told to stop.
- **Rollback is all-or-nothing.** Reverting a single host returns it to a protocol no peer speaks. An aborted window is finished (or reverted on every host in one generation), never left as a mixed fleet.

The per-host cost is a restart of `db-guardian.service` on three hosts and of `db-database-coordinator.service` and `db-database-coordinator-reconcile.service` on one, with no PostgreSQL restart; the fleet-wide cost is the control-plane gap above, which ends one reconcile interval after the primary is switched.

### Host placement is derived, not sequenced

This change has no ordering dependency on `openspec/changes/reallocate-server-service-roles`, and it neither waits for nor blocks it.

The unit names it references — `db-guardian.service`, `db-database-coordinator.service`, `db-databases.target` — are already the names on `master`, and the sibling change restates the same names, so naming is stable either way. Host placement is not a dependency but a derivation: the guardian module already computes which host is the database primary and which other hosts run guardians, and this change consumes those expressions instead of naming a host.

This change therefore:

- **SHALL** resolve the coordinator host from the guardian module's existing primary-host predicate — `isThisIOPrimaryHost` today, the generic `isThisPrimaryHost config.server.databasePrimaryHost` once the sibling change lands (`modules/nixos/server/database/guardian.nix:81`, `:83`, `:88`, `:197`); and
- **SHALL** resolve the guardian host set from `getOthersWhere (...)` today and `getOthersWhereExcept (...)` after (`guardian.nix:35`), so the certificate declarations follow the same expression that decides which hosts get `db-guardian.service`;
- **SHALL** work unchanged on today's topology: `nixio` as the database primary, `nixcloud` / `nixdev` / `nixserv` as guardians.

**No reissue when the primary moves.** The client identity is a role, not a hostname: one leaf with `CN=db-guardian-coordinator` and no subject alternative names, deployed to whichever host satisfies the predicate. When the sibling change moves the primary from `nixio` to `nixdb`, the same certificate and key move with the role — re-encrypted to `nixdb`'s sops recipients and removed from `nixio`'s — and nothing else changes: no new leaf, no allowlist edit (every guardian already allows that common name), and no guardian SAN set change unless the guardian host set itself changes. The only certificate that ever needs reissuing is a guardian leaf, and only if the name the coordinator dials for that host changes.
