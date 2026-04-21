## Context

The source plan chooses SeaweedFS as the first evaluation target after comparing alternatives, but explicitly limits scope to an all-in-one deployment that runs alongside MinIO rather than replacing it. The SeaweedFS notepad adds two important corrections: the repository already imports an upstream `services.seaweedfs` module, so the local module should be config-oriented rather than redefining the full option surface, and the earlier host-level implementation attempt was scope creep that had to be removed so the feature stays inside the module architecture.

This change touches storage modules, host role gating, proxy exposure, secrets, and docs, so a design document is useful to preserve those scope boundaries.

### Component Diagram

```text
modules/nixos/server/storage/default.nix
                |
                v
      seaweedfs evaluation module
                |
                +--> services.seaweedfs (upstream module options)
                |
                +--> server.proxy.virtualHosts.seaweedfs
                |
                +--> sops-managed S3 config secret
                |
                v
        IO primary host only
```

## Goals / Non-Goals

**Goals:**

- Add a module-oriented SeaweedFS evaluation deployment without touching existing MinIO behavior.
- Gate the deployment to the host selected by `server.ioPrimaryHost`.
- Expose only the S3-compatible endpoint through Caddy with TLS termination at the proxy.
- Keep SeaweedFS credentials and S3 policy configuration separate and sops-managed.
- Document the evaluation-only nature of the deployment.

**Non-Goals:**

- Data migration from MinIO or changes to existing bucket mounts.
- Multi-node SeaweedFS architecture, replication, WebDAV, or erasure coding.
- Host-specific service implementation files outside the intended module hierarchy.
- Public proxying of internal SeaweedFS control or gRPC ports.

## Decisions

### Decision 1: Use the imported upstream SeaweedFS module surface

**Choice:** Keep the local repository module focused on configuration and role gating, while relying on the already imported upstream `services.seaweedfs` option surface for component settings.

**Rationale:** The notepad explicitly records that redefining a parallel local option tree was unnecessary. Reusing the upstream module avoids duplicated option definitions and keeps the repository-specific layer small.

**Alternatives considered:**

- Define `server.storage.seaweedfs.*` options locally: duplicates upstream option surface and increases maintenance overhead.

### Decision 2: Gate deployment with `server.ioPrimaryHost`

**Choice:** Enable SeaweedFS only when `config.server.ioPrimaryHost == config.networking.hostName`.

**Rationale:** The plan explicitly warns against assuming a hostname like `nixio`. Using the role assignment keeps the deployment host-agnostic and aligned with existing server patterns.

### Decision 3: Keep S3 proxy configuration with the module

**Choice:** Define the SeaweedFS S3 virtual host alongside the SeaweedFS module configuration, proxying only the HTTP S3 endpoint and letting Caddy terminate TLS.

**Rationale:** The notepad shows that colocating proxy settings with the SeaweedFS module reduces scatter and allows the proxy port to reference the active SeaweedFS S3 configuration directly.

**Alternatives considered:**

- Put proxy configuration in a host-only file: increases coupling and repeats evaluation logic.

### Decision 4: Use filer S3 configuration secret path from the upstream layout

**Choice:** Provide SeaweedFS S3 identities and policies through `services.seaweedfs.filer.s3.config`, backed by a sops-managed JSON file.

**Rationale:** The notepad records that the upstream module nests S3 configuration under the filer rather than a top-level `services.seaweedfs.s3` path. Matching that layout prevents configuration drift.

## Risks / Trade-offs

**[Upstream module mismatch]** -> Repository assumptions may drift from the imported SeaweedFS module surface.  
*Mitigation:* Keep the local module thin and use upstream option paths directly.

**[Port conflicts on IO primary host]** -> SeaweedFS evaluation services may collide with existing host ports.  
*Mitigation:* Keep ports explicit in configuration and verify builds plus proxy exposure during validation.

**[Scope creep back into host files]** -> Future changes may try to implement service behavior in host directories again.  
*Mitigation:* Keep the module architecture explicit in docs and tasks, and preserve host files for wiring only.

**[Parallel storage confusion]** -> Operators may misread the evaluation deployment as a MinIO replacement.  
*Mitigation:* Document clearly that SeaweedFS runs alongside MinIO for evaluation only.

## Migration Plan

1. Add or update the storage module import for SeaweedFS evaluation.
2. Configure SeaweedFS service settings gated to the IO primary host.
3. Add the Caddy S3 endpoint and sops-backed S3 configuration.
4. Add docs describing evaluation scope and constraints.
5. Verify formatting, host build, and flake checks.
6. Roll back by disabling the module import and host wiring; no data migration is involved.

### Sequence Diagram

```text
Nix evaluation -> storage module import: include seaweedfs evaluation module
storage module -> server role check: compare ioPrimaryHost to hostName
role check -> services.seaweedfs: enable master/volume/filer/S3 on IO primary host
services.seaweedfs -> sops secret path: load filer S3 config JSON
module -> Caddy virtual host: proxy only the S3 HTTP endpoint
client -> Caddy: TLS request for SeaweedFS S3 endpoint
Caddy -> SeaweedFS S3 endpoint: forward HTTP request locally
```

## Open Questions

1. Whether existing MinIO policy documents can be reused directly or require transformation for SeaweedFS S3 identity format.
2. Which exact evaluation domain name should be reserved for the SeaweedFS S3 endpoint.
3. Whether additional docs are needed for future migration planning once evaluation is complete.
