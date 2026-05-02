## 1. Storage module foundation

- [x] 1.1 Add or refine the SeaweedFS evaluation module under `modules/nixos/server/storage/` using the existing upstream `services.seaweedfs` option surface
- [x] 1.2 Import the SeaweedFS evaluation module from `modules/nixos/server/storage/default.nix`
- [x] 1.3 Verify the SeaweedFS evaluation change does not modify existing MinIO configuration files or mount definitions

## 2. IO-primary deployment and proxy wiring

- [x] 2.1 Gate SeaweedFS evaluation to `config.server.ioPrimaryHost == config.networking.hostName`
- [x] 2.2 Configure the all-in-one SeaweedFS evaluation services and data paths on the IO primary host
- [x] 2.3 Add the Caddy virtual hosts needed for the SeaweedFS evaluation endpoints, with client-facing TLS termination at Caddy and the required backend transport settings per endpoint

## 3. Secrets and documentation

- [x] 3.1 Add separate sops-managed SeaweedFS TLS and JWT entries without overwriting MinIO secrets
- [x] 3.2 Wire the SeaweedFS proxy and service configuration to the sops-backed TLS and JWT material used for evaluation
- [x] 3.3 Add SeaweedFS evaluation documentation under the current NixOS server storage docs layout and update the relevant navigation or overview content to describe evaluation scope and constraints

## 4. Verification

- [x] 4.1 Run `nix fmt .` after Nix file changes
- [x] 4.2 Build the `server.ioPrimaryHost` NixOS configuration successfully
- [x] 4.3 Run `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` and confirm the SeaweedFS evaluation change does not introduce unrelated storage regressions
