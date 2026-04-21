## 1. Storage module foundation

- [ ] 1.1 Add or refine the SeaweedFS evaluation module under `modules/nixos/server/storage/` using the existing upstream `services.seaweedfs` option surface
- [ ] 1.2 Import the SeaweedFS evaluation module from `modules/nixos/server/storage/default.nix`
- [ ] 1.3 Verify the SeaweedFS evaluation change does not modify existing MinIO configuration files or mount definitions

## 2. IO-primary deployment and proxy wiring

- [ ] 2.1 Gate SeaweedFS evaluation to `config.server.ioPrimaryHost == config.networking.hostName`
- [ ] 2.2 Configure the all-in-one SeaweedFS evaluation services and data paths on the IO primary host
- [ ] 2.3 Add a Caddy virtual host that proxies only the SeaweedFS S3 HTTP endpoint with TLS termination at Caddy

## 3. Secrets and documentation

- [ ] 3.1 Add separate sops-managed SeaweedFS S3 configuration or credential entries without overwriting MinIO secrets
- [ ] 3.2 Wire the SeaweedFS filer S3 configuration to the secret-backed JSON path expected by the upstream module
- [ ] 3.3 Add `docs/src/components/seaweedfs.md` and update `docs/src/SUMMARY.md` to describe evaluation scope and constraints

## 4. Verification

- [ ] 4.1 Run `nix fmt .` after Nix file changes
- [ ] 4.2 Build the `server.ioPrimaryHost` NixOS configuration successfully
- [ ] 4.3 Run `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` and confirm the SeaweedFS evaluation change does not introduce unrelated storage regressions
