# host-service-redistribution Specification

## Purpose

Define how services are relocated between hosts according to the redistribution table, separating the combined IO, database, storage, and identity roles that previously ran on `nixio` and `nixcloud` onto dedicated hosts.

## ADDED Requirements

### Requirement: nixio retains proxy and ingress services

The `nixio` host SHALL retain Caddy reverse proxy, Cloudflare tunnel, cluster dashboard, and AdGuard, and SHALL remove PostgreSQL, pgAdmin, and MinIO.

#### Scenario: nixio retains ingress

- **WHEN** `nixio` configuration is evaluated
- **THEN** it SHALL enable Caddy reverse proxy, Cloudflare tunnel, cluster dashboard, and AdGuard

#### Scenario: nixio no longer runs database services

- **WHEN** `nixio` configuration is evaluated
- **THEN** it SHALL NOT enable PostgreSQL, pgAdmin, or Redis

#### Scenario: nixio no longer runs storage services

- **WHEN** `nixio` configuration is evaluated
- **THEN** it SHALL NOT enable MinIO or SeaweedFS evaluation services

### Requirement: nixdb runs database services

The `nixdb` host SHALL be configured to run PostgreSQL with all cluster databases and pgAdmin.

#### Scenario: nixdb is the database primary host

- **WHEN** `nixdb` configuration is evaluated
- **THEN** `config.server.databasePrimaryHost` SHALL match `nixdb`
- **AND** PostgreSQL with all cluster databases SHALL be enabled
- **AND** pgAdmin SHALL be enabled
- **AND** Redis SHALL be enabled

#### Scenario: nixdb does not run non-database services

- **WHEN** `nixdb` configuration is evaluated
- **THEN** it SHALL NOT enable Caddy proxy, MinIO, SeaweedFS evaluation, or Kanidm identity services

### Requirement: nixstore runs storage services

The `nixstore` host SHALL be configured to run MinIO and the SeaweedFS evaluation deployment (when enabled).

#### Scenario: nixstore is the storage primary host

- **WHEN** `nixstore` configuration is evaluated
- **THEN** `config.server.storagePrimaryHost` SHALL match `nixstore`
- **AND** MinIO SHALL be enabled
- **AND** SeaweedFS evaluation services SHALL be enabled when SeaweedFS is enabled

#### Scenario: nixstore does not run non-storage services

- **WHEN** `nixstore` configuration is evaluated
- **THEN** it SHALL NOT enable PostgreSQL, pgAdmin, Redis, Caddy proxy, or Kanidm identity services

### Requirement: nixauth runs identity services

The `nixauth` host SHALL be configured to run Kanidm identity via the reusable server identity module.

#### Scenario: nixauth is the auth primary host

- **WHEN** `nixauth` configuration is evaluated
- **THEN** `config.server.authPrimaryHost` SHALL match `nixauth`
- **AND** `server.identity.enable` SHALL be `true`
- **AND** Kanidm SHALL be deployed with the configured domain, TLS certificate, and backup schedule

#### Scenario: Host-local OAuth2 definitions remain on nixauth

- **WHEN** `nixauth` configuration is evaluated
- **THEN** the host-local `systems.oauth2` definitions and provisioning JSON SHALL be included

#### Scenario: nixauth does not run non-identity services

- **WHEN** `nixauth` configuration is evaluated
- **THEN** it SHALL NOT enable PostgreSQL, MinIO, SeaweedFS evaluation, or Caddy proxy

### Requirement: nixcloud retains application workloads

The `nixcloud` host SHALL retain Home Assistant, Homebox, Immich, Navidrome, Nextcloud, and Search, and SHALL remove Kanidm identity.

#### Scenario: nixcloud runs application services

- **WHEN** `nixcloud` configuration is evaluated
- **THEN** it SHALL enable Home Assistant, Homebox, Immich, Navidrome, Nextcloud, and Search

#### Scenario: nixcloud no longer runs identity services

- **WHEN** `nixcloud` configuration is evaluated
- **THEN** it SHALL NOT enable Kanidm or the identity module

### Requirement: Ingress remains centralized on nixio

The system SHALL ensure all ingress, reverse proxy, and Cloudflare tunnel duties remain exclusively on `nixio`.

#### Scenario: Proxy not deployed on other hosts

- **WHEN** any host other than `nixio` is evaluated
- **THEN** Caddy reverse proxy and Cloudflare tunnel SHALL NOT be enabled on that host

### Requirement: Other host roles unchanged

The system SHALL preserve existing service assignments for hosts not mentioned in the redistribution table.

#### Scenario: Media stays on nixarr

- **WHEN** `nixarr` configuration is evaluated
- **THEN** its service configuration SHALL be unchanged

#### Scenario: AI workloads stay on nixai

- **WHEN** `nixai` configuration is evaluated
- **THEN** its service configuration SHALL be unchanged

#### Scenario: Dev and CI stay on nixdev

- **WHEN** `nixdev` configuration is evaluated
- **THEN** its service configuration SHALL be unchanged

#### Scenario: Monitoring stays on nixmon

- **WHEN** `nixmon` configuration is evaluated
- **THEN** its monitoring stack configuration SHALL be unchanged

#### Scenario: Attic cache stays on nixserv

- **WHEN** `nixserv` configuration is evaluated
- **THEN** its Attic cache configuration SHALL be unchanged
