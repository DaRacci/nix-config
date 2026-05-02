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
                +--> server.proxy.virtualHosts.* (SeaweedFS evaluation endpoints)
                |
                +--> sops-managed mTLS + JWT material
                |
                v
        IO primary host only
```

## Goals / Non-Goals

**Goals:**

- Add a module-oriented SeaweedFS evaluation deployment without touching existing MinIO behavior.
- Gate the deployment to the host selected by `server.ioPrimaryHost`.
- Route the SeaweedFS evaluation endpoints through Caddy, including the S3-compatible endpoint and the additional component endpoints needed for evaluation.
- Keep SeaweedFS mTLS and inter-component JWT material separate and sops-managed.
- Document the evaluation-only nature of the deployment.

**Non-Goals:**

- Data migration from MinIO or changes to existing bucket mounts.
- Multi-node SeaweedFS architecture, replication, WebDAV, or erasure coding.
- Host-specific service implementation files outside the intended module hierarchy.
- Introducing a repository-local `server.storage.seaweedfs.*` option tree before the evaluation module shape has settled.

## Decisions

### Decision 1: Use the imported upstream SeaweedFS module surface

**Choice:** Keep the local repository module focused on configuration and role gating, while relying on the already imported upstream `services.seaweedfs` option surface for component settings.

**Rationale:** The notepad explicitly records that redefining a parallel local option tree was unnecessary. Reusing the upstream module avoids duplicated option definitions and keeps the repository-specific layer small.

**Alternatives considered:**

- Define `server.storage.seaweedfs.*` options locally: duplicates upstream option surface and increases maintenance overhead.

### Decision 2: Gate deployment with `server.ioPrimaryHost`

**Choice:** Enable SeaweedFS only when `config.server.ioPrimaryHost == config.networking.hostName`.

**Rationale:** The plan explicitly warns against assuming a hostname like `nixio`. Using the role assignment keeps the deployment host-agnostic and aligned with existing server patterns.

### Decision 3: Keep SeaweedFS proxy configuration with the module

**Choice:** Define the SeaweedFS evaluation virtual hosts alongside the SeaweedFS module configuration, routing the HTTP and gRPC endpoints needed for evaluation through Caddy while keeping the proxy configuration colocated with the service configuration.

**Rationale:** The notepad shows that colocating proxy settings with the SeaweedFS module reduces scatter and allows the proxy layer to reference the active SeaweedFS component configuration directly.

**Alternatives considered:**

- Put proxy configuration in a host-only file: increases coupling and repeats evaluation logic.

### Decision 4: Use sops-managed mTLS and JWT material for the evaluation deployment

**Choice:** Provide SeaweedFS evaluation security material through distinct sops-managed TLS certificates, keys, and JWT secrets used for proxy-to-component mTLS and inter-component authentication.

**Rationale:** The current evaluation implementation relies on Caddy-to-component mTLS and SeaweedFS JWT-based inter-component authentication. Keeping that material separate from MinIO secrets preserves evaluation isolation without prematurely designing long-term repository-local SeaweedFS option abstractions.

## Risks / Trade-offs

**[Upstream module mismatch]** -> Repository assumptions may drift from the imported SeaweedFS module surface.\
*Mitigation:* Keep the local module thin and use upstream option paths directly.

**[Port conflicts on IO primary host]** -> SeaweedFS evaluation services may collide with existing host ports.\
*Mitigation:* Keep ports explicit in configuration and verify builds plus proxy exposure during validation.

**[Scope creep back into host files]** -> Future changes may try to implement service behavior in host directories again.\
*Mitigation:* Keep the module architecture explicit in docs and tasks, and preserve host files for wiring only.

**[Parallel storage confusion]** -> Operators may misread the evaluation deployment as a MinIO replacement.\
*Mitigation:* Document clearly that SeaweedFS runs alongside MinIO for evaluation only.

## Migration Plan

1. Add or update the storage module import for SeaweedFS evaluation.
1. Configure SeaweedFS service settings gated to the IO primary host.
1. Add the Caddy evaluation endpoints and sops-backed mTLS/JWT material.
1. Add docs describing evaluation scope and constraints using the current server storage documentation layout.
1. Verify formatting, host build, and flake checks.
1. Roll back by disabling the module import and host wiring; no data migration is involved.

### Sequence Diagram

```text
Nix evaluation -> storage module import: include seaweedfs evaluation module
storage module -> server role check: compare ioPrimaryHost to hostName
role check -> services.seaweedfs: enable master/volume/filer/S3 on IO primary host
services.seaweedfs -> sops secrets: load SeaweedFS mTLS and JWT material
module -> Caddy virtual hosts: proxy SeaweedFS evaluation endpoints
client -> Caddy: TLS request for a SeaweedFS evaluation endpoint
Caddy -> SeaweedFS component: forward HTTP or gRPC traffic to the local service
```

## Open Questions

1. Which endpoints should remain part of the evaluation proxy surface long term versus being reduced after the evaluation stabilizes.
1. Which exact evaluation domain names should be reserved for the SeaweedFS endpoint set.
1. When to introduce a repository-local `server.storage.seaweedfs.*` abstraction after the current evaluation module shape settles.
