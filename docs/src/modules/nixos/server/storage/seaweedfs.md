# SeaweedFS Evaluation — Evaluation-Only Storage Service

## Purpose

SeaweedFS is deployed here as an evaluation-only storage service alongside MinIO.
It exists to validate SeaweedFS as a possible replacement candidate without changing existing MinIO-backed workloads or the repository's migration posture.
The evaluation deployment provides an all-in-one SeaweedFS stack on the storage primary host
so the repository can test endpoint shape, proxy integration, and service behaviour in a realistic environment while keeping the current MinIO setup intact.

## Entry Point

- **Main entry file**: `modules/nixos/server/storage/seaweedfs/default.nix`
- **Compatibility wrapper**: `modules/nixos/server/storage/seaweedfs.nix`
- **Supporting file**: `modules/nixos/server/storage/default.nix`
- **Component files**: `modules/nixos/server/storage/seaweedfs/{master,volume,filer,admin,worker,proxy,security,s3,tmpfiles,lib,options}.nix`

## Architecture / Services / Scope

- **Evaluation only**: this deployment does not replace MinIO and does not perform any migration.
- **IO primary only**: the module is gated by `config.server.ioPrimaryHost == config.networking.hostName`.
- **All-in-one topology**: the evaluation enables the SeaweedFS master, volume, filer, S3 endpoint, admin UI, and worker components on the coordinator host.
- **Proxy surface**: endpoints are exposed through the existing `server.proxy.virtualHosts` integration instead of host-local Caddy configuration.
  Current surface includes the master UI, filer, S3-compatible, volume, and admin endpoints under the `seaweedfs.${data.site.domain}` subtree.
  The master is served on `master.seaweedfs.${data.site.domain}` with `seaweedfs.${data.site.domain}` kept as an alias.
  Client-facing TLS terminates at Caddy; gRPC-backed component endpoints additionally get the backend transport settings required for SeaweedFS communication.
- **Master HTTP API is disabled**: `services.seaweedfs.master.disableHttp` removes `/dir/assign`, `/dir/lookup`, `/vol/*`, `/col/delete`, `/submit`, and the `/{fileId}` redirect.
  Those routes hand out file IDs and JWT write tokens without authentication, so only the master UI stays reachable over HTTP.
- **Operator auth**: admin and filer require Kanidm, and the master UI and volume UI are gated by path.
  All four share the `seaweedfs` Kanidm context, which is restricted to `sysadmin@auth.racci.dev`
  and uses one shared portal with the `seaweedfs.${data.site.domain}` cookie domain, so a login on any of them covers the rest.
  The S3 endpoint uses S3 SigV4/IAM rather than Kanidm and exposes a `*.s3.seaweedfs.${data.site.domain}` alias for virtual-hosted-style requests.
  The worker is not exposed through Caddy.
- **gRPC client restriction**: `security.toml` sets `allowed_commonNames` per gRPC service.
  These allowlists apply to direct gRPC peers; Caddy re-originates gRPC connections using each component's own certificate.
- **Option surface**: the module keeps the upstream `services.seaweedfs.*` namespace.
  This repository now vendors the module locally and extends it with repo-specific options,
  including `services.seaweedfs.volume.publicUrl` and `extraArgs` on all component services.

## S3 identities

Identities and their IAM policies are declared under `services.seaweedfs.filer.s3`:

```nix
services.seaweedfs.filer.s3 = {
  policies.attic = {
    Version = "2012-10-17";
    Statement = [
      {
        Effect = "Allow";
        Action = [ "s3:ListBucket" "s3:GetBucketLocation" ];
        Resource = "arn:aws:s3:::attic";
      }
      {
        Effect = "Allow";
        Action = [ "s3:GetObject" "s3:PutObject" "s3:DeleteObject" ];
        Resource = "arn:aws:s3:::attic/*";
      }
    ];
  };

  identities.attic.policies = [ "attic" ];
};
```

`services.seaweedfs.filer.s3.config` is the freeform S3 configuration document.
The `identities` and `policies` options are rendered into it, and any other key passes through unchanged.
Identity and policy lists are concatenated, and a name declared both ways is rejected.
Policy attribute names are the policy names identities reference, and the identity name is the S3 user name.

An identity reads `S3/<NAME>_ACCESS_KEY` and `S3/<NAME>_SECRET_KEY` from SOPS and passes them to the filer as
`S3_<NAME>_ACCESS_KEY` and `S3_<NAME>_SECRET_KEY` through a rendered environment file.
`accessKeySecret`, `accessKeyEnv`, and the `secretKey` equivalents override those names,
while `accessKey` and `secretKey` take a literal value instead of a reference.

### Buckets

Buckets are created by a `seaweedfs-s3-init` oneshot, keyed by bucket name:

```nix
services.seaweedfs.filer.s3.buckets.attic = {
  owner = "attic";
  versioning = "Enabled"; # optional
  quotaMB = 51200;        # optional
};
```

The owner is recorded on the bucket, which is what lets that identity reach it;
a bucket with no owner is only reachable by admin identities.
`withLock = true` enables S3 Object Lock, which also enables versioning and blocks suspending it.
`versioning` sets the versioning status, and `quotaMB` records a bucket quota.

Quota values are recorded only.
Turning an exceeded quota into a read-only bucket is a separate `s3.bucket.quota.enforce` pass, which this module does not schedule.

Everything else a bucket can carry, such as lifecycle rules, tags, CORS, encryption, ACLs,
and bucket policies, lives in S3 API state rather than in filer directory metadata managed here.
Those stay with the S3 client or the admin UI, and are not reconciled at boot.

The unit runs after the master and filer, feeds every bucket command in one shell session, and treats `already exists` as success, so it is safe on every boot.

## Secrets

SeaweedFS SOPS entries are separate from MinIO secrets and are used for:

- **mTLS between Caddy and SeaweedFS components**
- **JWT-based inter-component authentication inside SeaweedFS**

These entries live under the `SEAWEEDFS` secret tree on the storage primary host and include both JWT material
and TLS certificates/keys for the SeaweedFS component set.

### TLS trust chain

SeaweedFS TLS material uses the shared offline `Fleet mTLS Root CA` and a dedicated `SeaweedFS Intermediate CA`:

```text
Fleet mTLS Root CA
└── SeaweedFS Intermediate CA
    └── master, volume, filer, admin, client, worker leaves
```

`SEAWEEDFS/TLS/CA` is a PEM trust bundle.
It contains the original flat `SeaweedFS CA` and the `Fleet mTLS Root CA` until the first Fleet rollout completes,
because the currently deployed leaves may still be signed by the original CA.
After all components run the Fleet chains, reduce it to the Fleet root only.
TLS material is stored as binary SOPS files under `hosts/server/nixio/seaweedfs-tls/`: `CA`, `<SERVICE>_CRT`, and `<SERVICE>_KEY`.
Each `SEAWEEDFS/TLS/<SERVICE>_CRT` value is a chain ordered leaf first, then the SeaweedFS intermediate.
Leaves use both `serverAuth` and `clientAuth` because the same component certificate is used as a gRPC server and client certificate.
The root and intermediate private keys are kept offline.

The CA hierarchy, key custody, issuance, and rotation are documented in [Internal mTLS CA](../../../../security/internal_mtls_ca.md).
Component SANs must match the Caddy `tls_server_name` values: `master.seaweedfs.${data.site.domain}` for the master,
and `<service>.seaweedfs.${data.site.domain}` for volume, filer, and admin.
The master leaf also carries `seaweedfs.${data.site.domain}`, which stays a vhost alias for the pre-rename hostname.
`data.site.domain` is the configured proxy domain.

### Provisioning certificates

Leaves are issued by `provision-seaweedfs-certs`, which reads the Fleet root and the SeaweedFS intermediate from a KeePassXC vault:

```bash
provision-seaweedfs-certs --vault pki.kdbx --vault-password-file vault-pass
```

It writes the `CA` bundle (root plus intermediate) and one `<SERVICE>_CRT`/`<SERVICE>_KEY` pair per component,
each chain ordered leaf first then intermediate, and encrypts all of them as binary SOPS files.
Components default to master, volume, filer, admin, client, and worker.
Pass component names to limit a run and `--force` to rotate them, so `--force master` reissues only the master leaf.
That is the rotation that adds the `master.seaweedfs.${data.site.domain}` SAN.
Use `--dry-run` to print the planned SAN sets without writing anything.

## Operational Notes / Assumptions

- **Volume data plane stays open**: only `/ui/*` and `/status` on the volume vhost require authentication.
  Chunk reads by file ID and the `publicUrl` path used by the filer remain unauthenticated,
  which is why the volume cannot sit fully behind Kanidm.
- The evaluation deployment is separate from `server.storage.swfsMount`.
  The storage abstraction can use `weed mount` for SeaweedFS-backed workload mounts without changing the evaluation topology described here.
- `services.seaweedfs.volume.publicUrl` should match the external proxy hostname so volume servers advertise reachable URLs.
- This deployment is intended to shake out integration details first; repository-local abstractions can be added later if SeaweedFS proves to be a good fit.

## References

- [Storage Overview](../storage.md)
- [SeaweedFS upstream repository](https://github.com/seaweedfs/seaweedfs)
