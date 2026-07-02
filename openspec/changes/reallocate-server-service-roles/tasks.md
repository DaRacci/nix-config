# Tasks: Reallocate Server Service Roles

Implementation checklist. See [design.md](design.md) for how, specs/ for what.

---

## 1. Foundation — Allocation Options & Generic Helpers

Sets up the new role selectors so all downstream modules have something to resolve against. No service moves yet — deployable to all hosts with zero behavioral change.

- [ ] 1.1 Add `databasePrimaryHost`, `storagePrimaryHost`, `authPrimaryHost` to `allocations.server` in `modules/flake/allocations.nix` using `serverHostnamesEnum` type (spec: `cluster-role-allocations/spec.md`)
- [ ] 1.2 Map new allocations to `server.*` options in `modules/flake/apply/system.nix` alongside existing `ioPrimaryHost` / `monitoringPrimaryHost` (spec: `cluster-role-allocations/spec.md`)
- [ ] 1.3 Set concrete allocation values in `flake/nixos/flake-module.nix` — `databasePrimaryHost = "nixdb"`, `storagePrimaryHost = "nixstore"`, `authPrimaryHost = "nixauth"` (spec: `cluster-role-allocations/spec.md`)
- [ ] 1.4 Add `server.databasePrimaryHost`, `server.storagePrimaryHost`, `server.authPrimaryHost` options to `modules/nixos/server/default.nix` (spec: `database-primary-host/spec.md`, `storage-primary-host/spec.md`)
- [ ] 1.5 Generalize primary host helpers — add `isPrimaryHost`, `isThisPrimaryHost`, `getPrimaryHostConfig`, `getPrimaryHostAttr`, `getOthersWhereExcept` in `modules/nixos/server/default.nix`; refactor existing IO helpers (`isIOPrimaryHost`, etc.) to delegate to generics; add all helpers to `importModule` inherited set (design: Decision 2)
- [ ] 1.6 Update `docs/src/modules/flake/allocations.md` — document `databasePrimaryHost`, `storagePrimaryHost`, `authPrimaryHost`
- [ ] 1.7 Update `docs/src/modules/nixos/server/default.md` — document new server options and generic helpers

**Validation after Group 1**: `nix eval .#nixosConfigurations.nixio.config.server.databasePrimaryHost` to verify options resolve; `nix flake check` with devenv override to catch eval errors.

## 2. Database Module Rework

Reworks database module chain to gate on `databasePrimaryHost` instead of `ioPrimaryHost`. Guardian targets renamed (io- → db-) for clarity.

- [ ] 2.1 Update `modules/nixos/server/database/default.nix` — change `server.database.host` default to `localhost` when local host matches `databasePrimaryHost`, else `databasePrimaryHost` (spec: `database-primary-host/spec.md`, design: Decision 3)
- [ ] 2.2 Update `modules/nixos/server/database/postgres.nix` — gate `services.postgresql` block on `isThisPrimaryHost config.server.databasePrimaryHost`; resolve port via `getPrimaryHostAttr` with `databasePrimaryHost` (spec: `database-primary-host/spec.md`)
- [ ] 2.3 Update `modules/nixos/server/database/redis.nix` — gate Redis instance on `isThisPrimaryHost config.server.databasePrimaryHost`; resolve port via database primary; update `redis-mappings.json` path template from `ioPrimaryHost` to `databasePrimaryHost` (spec: `database-primary-host/spec.md`, design: Decision 3)
- [ ] 2.4 Move `hosts/server/nixio/redis-mappings.json` to `hosts/server/nixdb/redis-mappings.json` — coordinate with path change in 2.3 in same commit (design: Decision 3 Risk)
- [ ] 2.5 Update `modules/nixos/server/database/guardian.nix` — gate coordinator on `databasePrimaryHost`; use `getOthersWhereExcept config.server.databasePrimaryHost`; rename systemd targets/services (`io-databases.target` → `db-databases.target`, `wait-for-io` → `wait-for-db-primary`, `io-database-coordinator` → `db-database-coordinator`, `io-guardian` → `db-guardian`); update Guardian PSK reference from `IO_GUARDIAN_PSK` to `DB_GUARDIAN_PSK` (design: Decision 7)
- [ ] 2.6 Update `docs/src/modules/nixos/server/database.md` — document database primary host gating, guardian rename, new PSK name
- [ ] 2.7 Update `docs/src/components/io_guardian.md` — reflect new target/service names, database primary ownership

**Validation after Group 2**: `nix build .#nixosConfigurations.nixdb.config.system.build.toplevel` to verify database modules evaluate correctly on target host.

## 3. Storage Module Rework

Retargets storage modules (SeaweedFS, MinIO bucket placement) from IO primary to storage primary.

- [ ] 3.1 Update `modules/nixos/server/storage/seaweedfs.nix` — change gating from `config.server.ioPrimaryHost == config.networking.hostName` to `config.server.storagePrimaryHost == config.networking.hostName` (spec: `seaweedfs-io-primary-deployment/spec.md`, `storage-primary-host/spec.md`)
- [ ] 3.2 Update `modules/nixos/server/storage/bucket.nix` — if MinIO bucket declarations are conditional on `isThisIOPrimaryHost`, switch to `isThisPrimaryHost config.server.storagePrimaryHost` (spec: `storage-primary-host/spec.md`)
- [ ] 3.3 Update `docs/src/modules/nixos/server/storage.md` — document storage primary host gating for SeaweedFS and MinIO

**Validation after Group 3**: `nix build .#nixosConfigurations.nixstore.config.system.build.toplevel` to verify storage modules evaluate.

## 4. Identity Module Extraction

Extracts Kanidm identity from `nixcloud/identity.nix` into a reusable module under `modules/nixos/server/identity/`.

- [ ] 4.1 Create `modules/nixos/server/identity/default.nix` — define `server.identity` option tree (enable, domain, bindAddress, tlsCertificateDomain, backupSchedule) and `server.identity.kanidm` sub-options (groups, oauth2, adminPasswordFile, idmAdminPasswordFile, provisioningJsonFile); auto-configure Kanidm service, ACME cert with Cloudflare DNS, firewall rule, proxy vhost, and dashboard item when enabled (spec: `reusable-server-identity-module/spec.md`, design: Decision 5)
- [ ] 4.2 Create `docs/src/modules/nixos/server/identity.md` — document identity module options and auto-configuration
- [ ] 4.3 Register identity module docs in `docs/src/SUMMARY.md` under Server section

**Validation**: `nix eval .#nixosConfigurations.nixauth.config.server.identity.enable` to confirm option resolves; `nix flake check` with devenv override.

## 5. Host Configurations — New Hosts

Creates the three new dedicated host configs with their respective service scopes and secrets.

- [ ] 5.1 Create `hosts/server/nixdb/default.nix` — enable PostgreSQL, pgAdmin, Redis via database primary gating; configure sops secrets (PostgreSQL passwords, pgAdmin password, Redis password, `DB_GUARDIAN_PSK`); reference shared `hosts/server/secrets.yaml` for `fromAllServers` collection; import guardian module; add dashboard item (spec: `host-service-redistribution/spec.md`, `database-primary-host/spec.md`)
- [ ] 5.2 Create `hosts/server/nixstore/default.nix` — enable MinIO, SeaweedFS evaluation via storage primary gating; configure MinIO root credentials in sops; register SeaweedFS proxy vhosts; add dashboard item (spec: `host-service-redistribution/spec.md`, `storage-primary-host/spec.md`)
- [ ] 5.3 Create `hosts/server/nixauth/default.nix` — import identity module; set `server.identity.enable = true`; configure host-local groups, OAuth2 clients (`systems.oauth2`), provisioning JSON; set sops secrets (Kanidm admin password, provisioning JSON, Cloudflare DNS tokens for ACME) (spec: `host-service-redistribution/spec.md`, `reusable-server-identity-module/spec.md`, design: Decision 5)

**Validation after Group 5**: Build each new host config individually to verify service enablement and sops resolution.

## 6. Host Configurations — Slim Down nixio & nixcloud

Removes services that moved to dedicated hosts from the existing multipurpose hosts.

- [ ] 6.1 Update `hosts/server/nixio/default.nix` — remove `database.nix` and `storage.nix` imports; remove host-level PostgreSQL, pgAdmin, MinIO config; keep proxy, tunnel, dashboard, AdGuard imports; remove `hosts/server/nixio/minio/` directory (spec: `host-service-redistribution/spec.md`, design: Phase 4)
- [ ] 6.2 Update `hosts/server/nixcloud/default.nix` — remove `identity.nix` import; keep only application workload imports (Home Assistant, Immich, Nextcloud, Navidrome, Homebox, Search) (spec: `host-service-redistribution/spec.md`, design: Phase 3)
- [ ] 6.3 Create `docs/src/hosts/server/nixdb.md` — document service scope, secrets, guardian coordination
- [ ] 6.4 Create `docs/src/hosts/server/nixstore.md` — document service scope, MinIO + SeaweedFS deployment
- [ ] 6.5 Create `docs/src/hosts/server/nixauth.md` — document identity module usage, Kanidm secrets, ACME setup
- [ ] 6.6 Update `docs/src/hosts/server/nixio.md` — reflect reduced service scope (proxy, tunnel, dashboard, AdGuard only) — create page if it doesn't exist yet
- [ ] 6.7 Update `docs/src/hosts/server/nixcloud.md` — reflect identity removal, app-only scope — create page if it doesn't exist yet
- [ ] 6.8 Register new host docs in `docs/src/SUMMARY.md` under Hosts section

**Validation**: Build `nixio` and `nixcloud` — verify PostgreSQL, pgAdmin, MinIO removed from `nixio`; Kanidm removed from `nixcloud`.

## 7. Final Verification

Full validation pass across all affected configurations and hosts.

- [ ] 7.1 Run `nix fmt .` to format all Nix changes
- [ ] 7.2 Build `.#nixosConfigurations.nixio.config.system.build.toplevel`
- [ ] 7.3 Build `.#nixosConfigurations.nixdb.config.system.build.toplevel`
- [ ] 7.4 Build `.#nixosConfigurations.nixstore.config.system.build.toplevel`
- [ ] 7.5 Build `.#nixosConfigurations.nixauth.config.system.build.toplevel`
- [ ] 7.6 Build `.#nixosConfigurations.nixcloud.config.system.build.toplevel`
- [ ] 7.7 Run `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` for full evaluation check

---

## Task Dependency Summary

```
Group 1 (Foundation)
  ├── Group 2 (Database Rework)
  │     └── Group 5.1 (nixdb host config)
  ├── Group 3 (Storage Rework)
  │     └── Group 5.2 (nixstore host config)
  └── Group 4 (Identity Module)
        └── Group 5.3 (nixauth host config)
              └── Group 6 (Slim hosts + docs)
                    └── Group 7 (Final verification)
```

Groups 2, 3, and 4 are parallelizable. Groups 5 (new hosts) depends on the module rework being done. Group 6 (slim existing hosts) depends on new hosts existing. Group 7 is final.

## Risk Notes

- **Guardian rename (2.5)**: Systemd target/service renames during migration risk breaking service ordering if not coordinated. Must keep both old and new targets during migration transition (design: Decision 7, Risk: Guardian coordination).
- **Secret ownership (5.1, 5.2, 5.3)**: PostgreSQL secrets must move from nixio's sops config to nixdb's. MinIO creds to nixstore. Kanidm secrets + Cloudflare DNS tokens to nixauth. Duplicate Cloudflare tokens on both nixio and nixauth is intentional (design: Trade-off).
- **redis-mappings.json (2.4)**: Must move atomically with path change in `redis.nix` — if file doesn't exist at new path, Nix evaluation fails (design: Decision 3 Risk).
- **Helper generalization (1.5)**: Must keep `getOthersWhere` backward-compat alias so existing callers in guardian and other modules continue to work.
- **Host docs don't exist yet (6.6, 6.7)**: nixio and nixcloud host docs need creation, not just updates. Check if `docs/src/hosts/server/` directory needs creating.
