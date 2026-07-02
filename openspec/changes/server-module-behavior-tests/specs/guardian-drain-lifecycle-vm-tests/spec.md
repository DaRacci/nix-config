## ADDED Requirements

### Requirement: PG stop on IO primary propagates drain signal to dependent non-IO hosts

The system SHALL, when PostgreSQL is stopped on the IO primary host, emit a drain signal from `modules/nixos/server/database/guardian.nix` that reaches dependent non-IO hosts. Dependent hosts SHALL respond by draining their connection pools or service consumers before PG teardown completes. The `io-guardian` existing scenario covers connectivity reachability only; this requirement covers the lifecycle propagation mechanism end-to-end.

#### Scenario: Stop PG on IO primary, observe drain on dependent host

- **GIVEN** a multi-node VM scenario with an IO primary host (`nixio`) running PostgreSQL and a dependent non-IO host (`nixcloud`) running a service that connects to that PostgreSQL instance
- **WHEN** `systemctl stop postgresql` is executed on `nixio`
- **THEN** within the same test script, an observable drain signal SHALL appear on the dependent host before PostgreSQL reports `inactive`
- **AND** the dependent service's connection pool SHALL report zero active connections after drain completes
- **AND** the dependent service SHALL NOT attempt new connections to PostgreSQL while the drain is active
- **AND** the test SHALL observe the drain via a mechanism specific to the guardian's drain implementation (e.g., a sentinel file under `/run/guardian/`, a systemd unit property change, or a log line from the guardian service), NOT merely by polling PG port state

#### Scenario: Drain signal reaches multiple dependent hosts simultaneously

- **GIVEN** two dependent non-IO hosts (`nixcloud`, `nixdev`) both consuming the IO primary's PostgreSQL
- **WHEN** PostgreSQL is stopped on `nixio`
- **THEN** both dependent hosts SHALL receive the drain signal within the same test observation window
- **AND** both SHALL complete drain before PG reaches `inactive`

### Requirement: PG recovery on IO primary propagates undrain signal to dependent hosts

The system SHALL, when PostgreSQL recovers on the IO primary host, emit an undrain signal from `guardian.nix`. Dependent hosts SHALL re-establish connection pools and resume normal service within a bounded time window after PG reports ready.

#### Scenario: Start PG on IO primary, observe undrain on dependent host

- **GIVEN** PostgreSQL is stopped and drain is active on the dependent host (post-condition of the drain scenario)
- **WHEN** `systemctl start postgresql` is executed on `nixio`
- **AND** PostgreSQL reports `active (running)` on `nixio`
- **THEN** the dependent host SHALL receive the undrain signal within 30 seconds of PG becoming ready
- **AND** the dependent service's connection pool SHALL report active connections re-established
- **AND** the dependent service SHALL successfully execute a query against PostgreSQL after undrain completes

#### Scenario: Undrain is rejected if PG is not healthy

- **GIVEN** PostgreSQL fails to start fully (e.g., misconfigured `postgresql.conf` or data directory missing)
- **WHEN** the guardian detects PG health check failure
- **THEN** the undrain signal SHALL NOT be emitted
- **AND** dependent hosts SHALL remain in drained state

### Requirement: `wait-for-io` / `wait-for-io-databases` systemd gating blocks dependent units until IO is ready

The system SHALL gate dependent systemd services on the non-IO host behind `wait-for-io` or `wait-for-io-databases` targets. These targets SHALL NOT be reached until the guardian confirms IO primary databases are available and undrained. This ensures ordered startup without hard-coded `After=postgresql.service` references across hosts.

#### Scenario: Dependent service waits for IO databases target before starting

- **GIVEN** the dependent non-IO host is rebooted (cold start)
- **WHEN** all systemd units begin activation
- **THEN** `wait-for-io-databases.target` SHALL NOT be reached on the dependent host until the guardian on that host confirms connectivity to the IO primary's PostgreSQL
- **AND** any service with `Wants=wait-for-io-databases.target` SHALL remain in `activating` state until the target is reached
- **AND** after the target is reached, those services SHALL transition to `active`

#### Scenario: Guardian connectivity check uses application-level PG ping, not TCP port check

- **WHEN** the guardian performs its IO readiness check
- **THEN** it SHALL use a mechanism (e.g., `psql -c "SELECT 1"` or a custom NixOS service check) that validates PostgreSQL is accepting queries, not merely that port 5432 is open
- **AND** the test SHALL assert this distinction explicitly

### Requirement: Guardian module files produce observable behavior in multi-node topology

The test SHALL exercise `modules/nixos/server/database/guardian.nix` and `modules/nixos/server/database/postgres.nix` in a multi-node VM configuration where one host runs PostgreSQL and another runs a dependent consumer. The test SHALL NOT rely on single-host introspection (e.g., checking `systemctl status` on the IO primary alone).

#### Scenario: Multi-node topology with observable cross-host signal

- **GIVEN** a two-node VM scenario: `nixio` (runs PG + guardian) and `nixcloud` (runs consumer + `wait-for-io-databases`)
- **WHEN** the test script orchestrates PG stop/start lifecycle
- **THEN** all assertions about drain/undrain SHALL be based on observable state changes on the *dependent* host, not merely the IO host
- **AND** the test SHALL include at least one assertion that would fail if the guardian module were removed or disabled
