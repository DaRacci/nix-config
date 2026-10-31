# db-guardian-security Specification

## Purpose

Define the security properties of DB Guardian: how the coordinator and the guardians authenticate each other, what credential material exists, what the daemon is allowed to do to systemd, and which behaviours must remain unchanged so that the transport and privilege change does not alter availability semantics.

The guardian is the control plane that decides whether services with a database dependency may run. Its listener is reachable from the local subnet on every host that declares such a dependency, and the coordinator that drives it runs on the database primary. The properties below exist because that position gives the guardian the ability to stop services fleet-wide while it parses untrusted network input.

Unit and target names in this specification are the `db-`-prefixed names already present on `master` (`db-guardian.service`, `db-database-coordinator.service`, `db-database-coordinator-reconcile.timer`, `db-databases.target`). Host placement — which host is the database primary and therefore holds the coordinator identity — is derived, not hardcoded: it comes from the guardian module's existing primary-host predicate (`isThisIOPrimaryHost` today, the generic `isThisPrimaryHost config.server.databasePrimaryHost` once `openspec/changes/reallocate-server-service-roles` lands) and the guardian host set from `getOthersWhere` / `getOthersWhereExcept`. This specification refers to that role and never to a literal hostname, and it does not depend on the sibling change landing first.

## ADDED Requirements

### Requirement: Mutually authenticated encrypted transport

The system SHALL serve the guardian protocol only over TLS 1.2 or later, and SHALL require a client certificate signed by the DB Guardian Intermediate CA before any application frame is read.

#### Scenario: Coordinator connects with a valid client certificate

- **WHEN** the coordinator opens a connection to a guardian presenting a `clientAuth` certificate issued by the DB Guardian Intermediate CA
- **THEN** the TLS handshake SHALL complete and the guardian SHALL begin reading application frames

#### Scenario: Peer presents no client certificate

- **WHEN** a peer completes the TLS handshake without presenting a client certificate
- **THEN** the handshake SHALL fail and no application frame SHALL be parsed

#### Scenario: Plaintext client connects

- **WHEN** a client attempts a `ws://` connection to the guardian's canonical port
- **THEN** the connection SHALL be refused, because the listener accepts only TLS

#### Scenario: Certificate from another service's intermediate

- **WHEN** a client presents a certificate issued by the Alloy Dynamic Capture Intermediate CA or the SeaweedFS Intermediate CA
- **THEN** the guardian SHALL reject the handshake, because the guardian trusts only certificates that chain to the Fleet mTLS root through the DB Guardian Intermediate CA

#### Scenario: Protocol version floor

- **WHEN** a client offers only TLS 1.0 or TLS 1.1
- **THEN** the handshake SHALL be rejected

### Requirement: Client verifies server identity

The coordinator SHALL verify the guardian's certificate chain against the Fleet mTLS root and SHALL verify that the certificate covers the hostname it dialled, using the default behaviour of `ssl.create_default_context`.

#### Scenario: Correct guardian certificate

- **WHEN** the coordinator dials `<host>` and the presented `serverAuth` certificate has a subject alternative name matching `<host>`
- **THEN** the connection SHALL proceed

#### Scenario: Hostname not covered by the certificate

- **WHEN** the coordinator dials a name that does not appear in the certificate's subject alternative names
- **THEN** the connection SHALL fail with a hostname-verification error and no command SHALL be sent

#### Scenario: Certificate not chained to the fleet root

- **WHEN** the presented certificate does not chain to the Fleet mTLS root
- **THEN** the connection SHALL fail before any command is sent

#### Scenario: Verification cannot be disabled

- **WHEN** an operator inspects the client's TLS context or its command-line options
- **THEN** there SHALL be no option, flag, or environment variable that sets `verify_mode` to `ssl.CERT_NONE` or `check_hostname` to `False`

### Requirement: Client allowlist is mandatory and fails closed

The guardian SHALL require a non-empty set of permitted client common names, SHALL refuse to start when the set is empty, and SHALL close the connection when the presented common name is not in the set.

#### Scenario: Empty allowlist at startup

- **WHEN** the guardian starts with no `--allowed-cn` values
- **THEN** it SHALL exit with a non-zero status without binding a socket

#### Scenario: Empty allowlist at evaluation time

- **WHEN** a host evaluates a configuration where `server.database.guardian.allowedClientCommonNames` is `[ ]`
- **THEN** Nix evaluation SHALL fail with an assertion message naming the option

#### Scenario: Unknown common name

- **WHEN** a client presents a valid certificate whose common name is not in the allowlist
- **THEN** the guardian SHALL close the connection with WebSocket code 1008 before reading any command, and SHALL log the observed common name

#### Scenario: Known common name

- **WHEN** a client presents a certificate whose common name is `db-guardian-coordinator` and that name is in the allowlist
- **THEN** the guardian SHALL proceed to command handling

### Requirement: No shared static secret in the protocol

The system SHALL carry no pre-shared key, password, or bearer token in the guardian protocol, in its configuration, or in SOPS, and identity SHALL derive solely from the presented certificate.

#### Scenario: Guardian has no key material option

- **WHEN** the guardian binary is invoked
- **THEN** it SHALL accept no `--psk-file` argument and read no `GUARDIAN_PSK_FILE` environment variable

#### Scenario: Client sends no authentication frame

- **WHEN** the coordinator sends its first frame
- **THEN** that frame SHALL be a `command`, and no `{"type":"auth"}` message SHALL be sent

#### Scenario: Stale client sends an authentication frame

- **WHEN** a client sends `{"type":"auth", ...}` as its first frame
- **THEN** the guardian SHALL respond with an error naming the unknown message type and SHALL not execute any command

#### Scenario: Secret removed from SOPS

- **WHEN** the repository is searched for `DB_GUARDIAN_PSK`
- **THEN** no declaration, credential, argument, or documentation reference SHALL remain

#### Scenario: No vestigial key comparison

- **WHEN** the guardian source is inspected for a secret comparison
- **THEN** no constant-time or non-constant-time comparison of a shared secret SHALL exist, because no shared secret exists

### Requirement: Dedicated certificate authority for guardian identity

The system SHALL issue guardian certificates from a `DB Guardian Intermediate CA` that is separate from every other service intermediate and subordinate to the Fleet mTLS Root CA.

#### Scenario: Guardian leaves are scoped to the guardian

- **WHEN** a guardian certificate is issued
- **THEN** it SHALL be signed by the DB Guardian Intermediate CA, and server leaves SHALL carry `serverAuth` extended key usage while the coordinator leaf SHALL carry `clientAuth`

#### Scenario: Monitoring identity cannot drive the guardian

- **WHEN** a host holding a valid `alloy-capture-relay` certificate, and the Alloy intermediate key, attempts to drive a guardian
- **THEN** the attempt SHALL fail, because the Alloy intermediate cannot mint a certificate that chains through the DB Guardian Intermediate CA

#### Scenario: Server certificates are per host

- **WHEN** server certificates are issued for guardian hosts
- **THEN** each host SHALL receive its own leaf whose subject alternative names include the bare hostname and `<host>.localdomain`, plus `<host>.${server.proxy.domain}` on hosts where that option is defined, and no certificate SHALL be shared between hosts

A SAN cannot be generated from an option that has no value, and `server.proxy.domain` is undefined on the guardian hosts, so their leaves carry the bare name and `<host>.localdomain`. The bare name is the one the coordinator dials.

#### Scenario: Single coordinator identity

- **WHEN** the coordinator authenticates to any guardian
- **THEN** it SHALL present the single `db-guardian-coordinator` client certificate, deployed only to the database primary host

### Requirement: Least-privilege daemon identity

The guardian SHALL run as a dedicated unprivileged system user, and its ability to change systemd state SHALL be limited to starting and stopping `db-databases.target`.

#### Scenario: Daemon runs unprivileged

- **WHEN** `db-guardian.service` is running
- **THEN** its main process SHALL run as the `db-guardian` user, not as `root`

#### Scenario: Permitted unit transition

- **WHEN** the daemon requests `org.freedesktop.systemd1.manage-units` for `db-databases.target` with verb `start` or `stop`
- **THEN** polkit SHALL authorise the request without a password prompt

#### Scenario: Different unit

- **WHEN** the daemon requests a start, stop, restart, or reload of any other unit
- **THEN** polkit SHALL deny the request

#### Scenario: Different verb on the permitted unit

- **WHEN** the daemon requests `restart`, `reload`, `try-restart`, or a unit-file operation on `db-databases.target`
- **THEN** polkit SHALL deny the request

#### Scenario: Subject outside the daemon

- **WHEN** any user other than `db-guardian` requests `manage-units` for `db-databases.target`
- **THEN** the rule SHALL not apply, and authorisation SHALL be decided by the default policy

#### Scenario: Capabilities removed

- **WHEN** `db-guardian.service` is inspected
- **THEN** it SHALL have an empty `CapabilityBoundingSet`, `NoNewPrivileges = true`, and `ProtectSystem = "strict"`

### Requirement: Availability semantics unchanged

The system SHALL preserve the existing drain, undrain, reconciliation, and retry behaviour exactly, so that the transport and privilege change is not observable in service ordering.

#### Scenario: Drain stops the target

- **WHEN** the coordinator sends `drain` and the guardian accepts it
- **THEN** the guardian SHALL stop `db-databases.target`, which stops every service bound to it

#### Scenario: Undrain starts the target

- **WHEN** the coordinator sends `undrain` and the guardian accepts it
- **THEN** the guardian SHALL start `db-databases.target`

#### Scenario: Repeated commands are idempotent

- **WHEN** a guardian receives `drain` while already drained, or `undrain` while already undrained
- **THEN** it SHALL report success without an error

#### Scenario: Command vocabulary is closed

- **WHEN** a client sends any action other than `drain` or `undrain`
- **THEN** the guardian SHALL reject it and SHALL change no unit state

#### Scenario: Reconciliation continues

- **WHEN** `db-database-coordinator-reconcile.timer` fires every 5 minutes while the coordinator is active
- **THEN** it SHALL re-send `undrain` to every guardian, recovering hosts that stopped their target later

#### Scenario: Undrain retry

- **WHEN** an `undrain` fails because a guardian is unreachable
- **THEN** the coordinator SHALL retry every 30 seconds until every guardian is reachable, and `--fail-fast` SHALL abort the remaining hosts on the first failure

### Requirement: Certificate material is sourced from SOPS as binary files

The system SHALL obtain all guardian certificate material from SOPS-encrypted files referenced through `sops.secrets`, passed to the units as systemd credentials.

#### Scenario: Certificates are not inline values

- **WHEN** a guardian certificate or key is stored
- **THEN** it SHALL be a binary SOPS file under `hosts/server/<host>/db-guardian-tls/`, declared with `format = "binary"`, not an inline YAML scalar

#### Scenario: Only the owning host can decrypt its private key

- **WHEN** a host's guardian secrets are encrypted
- **THEN** the recipient set SHALL be selected by the existing `path_regex: hosts/server/<host>/` creation rule for that host, so a guardian's private key is not decryptable by another guardian

#### Scenario: Units read certificates as credentials

- **WHEN** `db-guardian.service`, `db-database-coordinator.service`, or `db-database-coordinator-reconcile.service` starts
- **THEN** certificate paths SHALL be supplied via `LoadCredential` and referenced as `%d/<name>` in `ExecStart`, not read from a world-readable path

### Requirement: Derived alignment with database primary host placement

The system SHALL resolve the coordinator identity and the guardian host set from the same expressions that decide which units exist, so that this capability is correct on today's topology (`nixio` as the database primary; `nixcloud`, `nixdev`, `nixserv` as guardians) and remains correct when the primary moves.

#### Scenario: Coordinator certificate follows the database primary

- **WHEN** the host satisfying the guardian module's primary-host predicate changes — including when `reallocate-server-service-roles` moves it to `nixdb`
- **THEN** the client certificate and key SHALL be declared on the host matching that predicate, and no module code SHALL name a literal host for the coordinator

#### Scenario: Guardian host set is derived

- **WHEN** a host gains or loses a `server.database.postgres` or `server.database.redis` declaration
- **THEN** the set of hosts running a guardian and the SANs issued for them SHALL follow from that declaration without a hardcoded host list

#### Scenario: Moving the primary needs no reissue

- **WHEN** the primary role moves to another host
- **THEN** the same `db-guardian-coordinator` leaf SHALL move with it, re-encrypted to the new host's recipients, and no new client certificate SHALL be issued and no `allowedClientCommonNames` entry SHALL change

#### Scenario: Names are independent of the sibling change

- **WHEN** `openspec/changes/reallocate-server-service-roles` is applied, or has not been applied
- **THEN** `db-guardian.service`, `db-database-coordinator.service`, and `db-databases.target` SHALL keep the names used here, and only the host satisfying the primary predicate SHALL change
