# Reallocate Server Service Roles

Separate overloaded server roles into dedicated hosts to reduce blast radius, simplify operations, and prepare each service area for independent scaling.

## Why

The `nixio` host currently serves as a combined ingress gateway, database primary, storage primary, and dashboard host. It runs Caddy, Cloudflare tunnel, AdGuard, PostgreSQL, pgAdmin, MinIO, and the cluster dashboard. Similarly, `nixcloud` bundles Kanidm identity alongside all application workloads (Home Assistant, Immich, Nextcloud, Navidrome, etc.).

This coupling creates several problems:

- **Blast radius**: A storage issue on `nixio` can take down the proxy, losing access to every service. A database restart affects proxied traffic.
- **Operational friction**: Any host maintenance on `nixio` requires coordinated downtime across multiple service areas. Tracing a database performance problem means filtering through proxy logs.
- **Scaling ceiling**: `nixio` cannot be upgraded or replaced for storage without affecting ingress. `nixcloud` cannot be upgraded for identity without affecting all applications.
- **Config coupling**: The server module defaults (`server.ioPrimaryHost`) conflate reverse proxy, database, and storage responsibilities into a single option, making it hard to reason about which services live where.

Splitting these roles onto dedicated hosts—`nixdb` (database), `nixstore` (storage), `nixauth` (identity)—lets each area evolve independently, matches the deployment to actual resource needs, and keeps the ingress layer stable while other roles rotate.

## What Changes

This change introduces new cluster role allocation options and server module options so that the database, storage, and identity concerns can be assigned to dedicated hosts. It then redistributes services from `nixio` and `nixcloud` to those new hosts, and extracts the Kanidm identity configuration into a generalized server module.

### New cluster role allocation options

Add `databasePrimaryHost`, `storagePrimaryHost`, and `authPrimaryHost` to `modules/flake/allocations.nix` under `allocations.server`, following the existing `monitoringPrimaryHost` pattern. Each option accepts a single server hostname via `serverHostnamesEnum`.

### New server module role options

Add `server.databasePrimaryHost`, `server.storagePrimaryHost`, and `server.authPrimaryHost` to the server module options in `modules/nixos/server/default.nix`, mapped from the flake allocations.

Update the database helper defaults so they key off `server.databasePrimaryHost` instead of `server.ioPrimaryHost`. Update the storage module gating (SeaweedFS evaluation, MinIO placement, mount backends) to key off `server.storagePrimaryHost`.

### Database host separation

Move shared PostgreSQL and pgAdmin from `nixio` to `nixdb`. The database module helpers (`postgres.nix`, `redis.nix`, `guardian.nix`) will reference `server.databasePrimaryHost` for deciding where to run primary instances and where to collect remote database registrations.

Applications that declare `server.database.postgres.<name>` will continue to work identically; only the host that runs PostgreSQL changes.

### Storage host separation

Move MinIO (and any related shared object storage concerns) from `nixio` to `nixstore`. The SeaweedFS evaluation deployment currently gated to `server.ioPrimaryHost` moves to `server.storagePrimaryHost` instead.

Storage mount helpers (`swfsMount`, bucket management) will reference the storage primary for backend service endpoints.

### Reusable server identity module

Extract the Kanidm identity configuration from `hosts/server/nixcloud/identity.nix` into a generalized module at `modules/nixos/server/identity/`. The module will:

- Accept the Kanidm server domain, TLS certificate domain, bind address, and backup schedule as configurable options
- Define a `server.identity.kanidm` option tree for provisioning data (groups, OAuth2 clients, scope maps)
- Set up the proxy virtual host, ACME certificate, and firewall rules automatically
- Register a dashboard item when `server.dashboard.enable` is true

Host-local config on `nixauth` will continue to define the OAuth2 client definitions (`systems.oauth2`), provisioning JSON, and any site-specific settings.

### Host service redistribution

| Host    | Retained services                                      | Removed to                  |
|---------|-------------------------------------------------------|-----------------------------|
| `nixio` | Caddy proxy, Cloudflare tunnel, dashboard, AdGuard     | PostgreSQL, pgAdmin, MinIO |
| `nixdb` | —                                                      | PostgreSQL, pgAdmin         |
| `nixstore` | —                                                    | MinIO, SeaweedFS evaluation |
| `nixauth` | —                                                     | Kanidm (from nixcloud)      |
| `nixcloud` | Home Assistant, Homebox, Immich, Navidrome, Nextcloud, Search | Kanidm identity              |

Ingress and network duties stay on `nixio`. Application workloads stay on `nixcloud`. Media stays on `nixarr`. AI stays on `nixai`. Dev/CI stays on `nixdev`. Monitoring stays on `nixmon`. Attic cache stays on `nixserv`.

## Capabilities

### New capabilities

#### capability: cluster-role-allocations

The flake SHALL expose `allocations.server.databasePrimaryHost`, `allocations.server.storagePrimaryHost`, and `allocations.server.authPrimaryHost` as configurable options accepting any server hostname.

- **WHEN** `allocations.server.databasePrimaryHost` is set
- **THEN** the value SHALL be mapped to `server.databasePrimaryHost` on all server hosts via `modules/flake/apply/system.nix`

- **WHEN** `allocations.server.storagePrimaryHost` is set
- **THEN** the value SHALL be mapped to `server.storagePrimaryHost` on all server hosts

- **WHEN** `allocations.server.authPrimaryHost` is set
- **THEN** the value SHALL be mapped to `server.authPrimaryHost` on all server hosts

#### capability: database-primary-host

The system SHALL provide a `server.databasePrimaryHost` option that determines which host runs primary database services (PostgreSQL, pgAdmin, Redis).

- **WHEN** `server.databasePrimaryHost` matches the local host
- **THEN** that host SHALL enable PostgreSQL with all cluster databases, pgAdmin, and Redis
- **WHEN** `server.databasePrimaryHost` does not match the local host
- **THEN** that host SHALL NOT enable PostgreSQL or Redis service instances

- **WHEN** `server.database.host` default is evaluated
- **THEN** it SHALL default to `"localhost"` on the database primary host and `server.databasePrimaryHost` on all other hosts

#### capability: storage-primary-host

The system SHALL provide a `server.storagePrimaryHost` option that determines which host runs primary storage services (MinIO cluster master, SeaweedFS evaluation deployment, shared object storage).

- **WHEN** `server.storagePrimaryHost` matches the local host
- **THEN** that host SHALL enable MinIO and SeaweedFS evaluation services
- **WHEN** `server.storagePrimaryHost` does not match the local host
- **THEN** that host SHALL NOT enable MinIO or SeaweedFS evaluation service instances

- **WHEN** storage mount helpers resolve the storage service endpoint
- **THEN** they SHALL use `server.storagePrimaryHost` instead of `server.ioPrimaryHost`

#### capability: reusable-server-identity-module

The system SHALL provide a `modules/nixos/server/identity/` module that generalizes Kanidm identity deployment as a reusable NixOS module.

- **WHEN** `server.identity.enable` is `true`
- **THEN** the system SHALL deploy Kanidm with the configured domain, TLS certificate, bind address, and backup schedule

- **WHEN** `server.identity.kanidm.groups` is populated
- **THEN** those groups SHALL be provisioned on Kanidm startup

- **WHEN** `server.identity.kanidm.oauth2` clients are defined
- **THEN** those clients SHALL be registered in Kanidm

- **WHEN** `server.dashboard.enable` is `true` and the auth host runs the proxy
- **THEN** the module SHALL register a dashboard item for Kanidm

- **WHEN** the identity module is enabled
- **THEN** it SHALL configure the proxy virtual host, ACME certificate, and open the Kanidm bind port

#### capability: host-service-redistribution

The system SHALL relocate services between hosts as described in the redistribution table.

- **WHEN** `nixdb` is configured
- **THEN** it SHALL run PostgreSQL with all cluster databases and pgAdmin
- **WHEN** `nixstore` is configured
- **THEN** it SHALL run MinIO and the SeaweedFS evaluation deployment (when enabled)
- **WHEN** `nixauth` is configured
- **THEN** it SHALL run Kanidm identity via the reusable server identity module

### Modified capabilities

#### `seaweedfs-io-primary-deployment` (spec: `seaweedfs-io-primary-deployment`)

The requirement "SeaweedFS evaluation services run only on the IO primary host" SHALL change to "SeaweedFS evaluation services run only on the storage primary host."

- **WHEN** a host's `networking.hostName` matches `config.server.storagePrimaryHost`
- **THEN** that host SHALL enable the SeaweedFS evaluation services

- **WHEN** a host's `networking.hostName` does not match `config.server.storagePrimaryHost`
- **THEN** that host SHALL NOT enable the SeaweedFS evaluation services

#### `seaweedfs-s3-proxy` (spec: `seaweedfs-s3-proxy`)

The requirement "SeaweedFS evaluation endpoints are exposed through Caddy on the IO primary host" SHALL change. Proxy routing to SeaweedFS endpoints SHALL resolve through the storage primary host.

- **WHEN** a proxy vhost for a SeaweedFS endpoint is evaluated
- **THEN** the back-end target SHALL resolve to the storage primary host instead of assuming localhost on the IO primary

### Unchanged capabilities

The following existing specs are unaffected by this change:

- `seaweedfs-storage-module` — module import structure is host-agnostic
- `swfs-mount-abstraction` — mount interface is host-agnostic
- `swfs-mount-backends` — backend behavior is host-agnostic
- `swfs-mount-health-recovery` — health check behavior is host-agnostic
- `swfs-mount-documentation` — documentation format is host-agnostic
- `proxy-extension-registry` — extension registry and ordering are host-agnostic
- `proxy-extension-authoring` — extension authoring pattern is host-agnostic
- `module-structure` — monitoring allocation pattern is unchanged
- `seaweedfs-evaluation-documentation` — documentation scope is unchanged
- `seaweedfs-evaluation-secrets` — secret management approach is unchanged

## Non-goals

- **Re-architecting the proxy layer**: Caddy and all proxy extensions remain on `nixio`. No changes to how vhosts are defined, how extensions register, or how config is generated.
- **Migrating application workloads**: Immich, Nextcloud, Home Assistant, Navidrome, Homebox, Search stay on `nixcloud`. No application is relocated.
- **Changing MinIO to SeaweedFS**: The storage host separation does not mandate a storage backend migration. MinIO and SeaweedFS evaluation both move to `nixstore`.
- **Refactoring the monitoring stack**: Monitoring stays on `nixmon`. No allocation or module changes to monitoring.
- **Changing distributed build allocation**: Builders stay on `nixdev` and other assigned hosts. No changes to `distributedBuilders`.
- **Adding new services**: This change does not introduce new software or features. It only reallocates and generalizes existing services.
- **Modifying the existing Kanidm provisioning schema**: The `systems.oauth2` structure, group definitions, scope maps, and claim maps remain as they are today.

## Impact

### Host configurations

- `hosts/server/nixio/default.nix` — remove PostgreSQL, pgAdmin, and MinIO service configuration
- `hosts/server/nixcloud/identity.nix` — move Kanidm config to the new identity module; host keeps only OAuth2 client definitions (`systems.oauth2`) and provisioning data
- `hosts/server/nixdb/default.nix` — new host config running PostgreSQL + pgAdmin
- `hosts/server/nixstore/default.nix` — new host config running MinIO + SeaweedFS
- `hosts/server/nixauth/default.nix` — new host config running Kanidm via identity module
- `hosts/server/shared/` — verify shared configs do not assume all roles on `nixio`

### Module files

- `modules/flake/allocations.nix` — add `databasePrimaryHost`, `storagePrimaryHost`, `authPrimaryHost`
- `modules/flake/apply/system.nix` — map new allocation options to server module options
- `modules/nixos/server/default.nix` — add `server.databasePrimaryHost`, `server.storagePrimaryHost`, `server.authPrimaryHost` options
- `modules/nixos/server/database/default.nix` — update `server.database.host` default to use `server.databasePrimaryHost`
- `modules/nixos/server/database/postgres.nix` — gate primary PostgreSQL instance on `server.databasePrimaryHost`
- `modules/nixos/server/database/redis.nix` — gate primary Redis instance on `server.databasePrimaryHost`
- `modules/nixos/server/storage/seaweedfs.nix` — gate SeaweedFS evaluation on `server.storagePrimaryHost`
- `modules/nixos/server/storage/bucket.nix` — gate MinIO placement on `server.storagePrimaryHost`
- `modules/nixos/server/identity/default.nix` — new reusable identity module

### Documentation

- `docs/modules/nixos/server/identity.md` — create documentation for the new identity module
- `docs/modules/nixos/server/database.md` — update to reflect database primary host separation
- `docs/modules/nixos/server/storage.md` — update to reflect storage primary host separation
- `docs/flake/allocations.md` — update with new role allocation options
- `docs/hosts/server/nixdb.md` — create new host documentation
- `docs/hosts/server/nixstore.md` — create new host documentation
- `docs/hosts/server/nixauth.md` — create new host documentation
- `docs/hosts/server/nixio.md` — update to reflect reduced service scope
- `docs/hosts/server/nixcloud.md` — update to reflect identity removal

### Existing spec updates

- `openspec/specs/seaweedfs-io-primary-deployment/spec.md` — update host gating from `server.ioPrimaryHost` to `server.storagePrimaryHost`
- `openspec/specs/seaweedfs-s3-proxy/spec.md` — update back-end target resolution to storage primary host
