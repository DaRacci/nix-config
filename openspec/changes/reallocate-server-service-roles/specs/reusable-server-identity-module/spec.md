# reusable-server-identity-module Specification

## Purpose

Define how the Kanidm identity configuration is extracted from `hosts/server/nixcloud/identity.nix` into a generalized, reusable NixOS module at `modules/nixos/server/identity/`, with configurable options for domain, TLS, bind address, and backup schedule, while leaving host-local OAuth2 definitions and provisioning data at the host layer.

## ADDED Requirements

### Requirement: Reusable identity module exists

The system SHALL provide a NixOS module at `modules/nixos/server/identity/default.nix` that generalizes Kanidm identity deployment and is importable via the `importModule` pattern from `modules/nixos/server/default.nix`.

#### Scenario: Module importable from server default.nix

- **WHEN** the server module loads
- **THEN** the identity module SHALL be available for import via `importModule ./identity {}`

#### Scenario: Module defines server.identity option tree

- **WHEN** the identity module is imported
- **THEN** it SHALL expose `server.identity` as an option tree with sub-options for enable, domain, tlsCertificateDomain, bindAddress, and backupSchedule

#### Scenario: Module defines server.identity.kanidm option tree

- **WHEN** the identity module is imported
- **THEN** it SHALL expose `server.identity.kanidm` with sub-options for groups and oauth2 client definitions

### Requirement: Module deploys Kanidm when enabled

The identity module SHALL deploy Kanidm with the configured domain, TLS certificate, bind address, and backup schedule when `server.identity.enable` is `true`.

#### Scenario: Kanidm service deployed

- **WHEN** `server.identity.enable` is `true`
- **THEN** the system SHALL enable the Kanidm systemd service on that host

#### Scenario: Kanidm configured with module options

- **WHEN** `server.identity.enable` is `true`
- **THEN** Kanidm SHALL listen on the configured `bindAddress` and serve the configured `domain`
- **AND** TLS SHALL be configured for the configured `tlsCertificateDomain`

#### Scenario: Backup schedule configured

- **WHEN** `server.identity.enable` is `true` and `backupSchedule` is set
- **THEN** the module SHALL configure automated Kanidm backups according to the specified schedule

### Requirement: Groups provisioned on startup

The module SHALL provision Kanidm groups defined in `server.identity.kanidm.groups` on Kanidm startup.

#### Scenario: Groups created at deployment

- **WHEN** `server.identity.kanidm.groups` is populated with group definitions
- **THEN** those groups SHALL be created in Kanidm during initial provisioning or re-provisioning

#### Scenario: Idempotent group provisioning

- **WHEN** Kanidm restarts and groups already exist
- **THEN** the provisioning logic SHALL NOT duplicate or overwrite existing group definitions

### Requirement: OAuth2 clients registered

The module SHALL register OAuth2 clients defined in `server.identity.kanidm.oauth2` within Kanidm.

#### Scenario: OAuth2 clients registered at deployment

- **WHEN** `server.identity.kanidm.oauth2` contains client definitions with scope maps
- **THEN** those clients SHALL be registered in Kanidm during initial provisioning

#### Scenario: Host-local OAuth2 definitions preserved

- **WHEN** the identity module is enabled on the auth host
- **THEN** the host config on `nixauth` SHALL continue defining `systems.oauth2`, provisioning JSON, and site-specific settings outside the module's `server.identity.kanidm` option tree

### Requirement: Proxy vhost and ACME configured automatically

The identity module SHALL configure the proxy virtual host, ACME certificate, and firewall rules automatically when `server.identity.enable` is `true`.

#### Scenario: Proxy virtual host created

- **WHEN** `server.identity.enable` is `true`
- **THEN** the module SHALL register a Caddy virtual host for the configured Kanidm domain

#### Scenario: ACME certificate provisioned

- **WHEN** `server.identity.enable` is `true`
- **THEN** the module SHALL configure ACME TLS certificate provisioning for the configured `tlsCertificateDomain`

#### Scenario: Firewall port opened

- **WHEN** `server.identity.enable` is `true`
- **THEN** the module SHALL open the Kanidm bind port in the host firewall

### Requirement: Dashboard item registered

The identity module SHALL register a dashboard item for Kanidm when `server.dashboard.enable` is `true` and the auth host runs the proxy.

#### Scenario: Dashboard item created on proxy host

- **WHEN** `server.dashboard.enable` is `true` and `server.identity.enable` is `true` on the ingress-proxy host
- **THEN** the module SHALL register a Kanidm dashboard item with name, URL, and icon

#### Scenario: No dashboard item on non-proxy host

- **WHEN** `server.identity.enable` is `true` but the host does not run the ingress proxy
- **THEN** the module SHALL NOT register a dashboard item
