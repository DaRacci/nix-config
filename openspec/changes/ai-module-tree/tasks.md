## 1. Package: mnemosyne-mcp

- [ ] 1.1 Create `pkgs/python/mnemosyne-mcp.nix` — `mnemosyne-memory` with `mcp` and `anyio` extra deps, `mnemosyne mcp --transport sse` functional
- [ ] 1.2 Expose `mnemosyne-mcp` in `pkgs/default.nix`
- [ ] 1.3 Verify package builds: `nix build .#mnemosyne-mcp`

## 2. Module tree scaffolding

- [ ] 2.1 Create `modules/nixos/ai/default.nix` — imports all modules under `ai/`, gated behind `mkIf cfg.enable` pattern
- [ ] 2.2 Import `modules/nixos/ai` in `modules/nixos/default.nix`

## 3. Mnemosyne NixOS module

- [ ] 3.1 Create `modules/nixos/ai/mnemosyne.nix` with full option tree (enable, dataDir, syncServer, mcpServer, syncClients, caddy) using `let` block for lib imports
- [ ] 3.2 Implement sync server systemd service — `mnemosyne sync serve` bound to configurable host:port, using `pkgs.mnemosyne-memory`, `MNEMOSYNE_DATA_DIR` env, DynamicUser with state directory
- [ ] 3.3 Implement MCP server systemd service — `mnemosyne mcp --transport sse`, using `pkgs.mnemosyne-mcp`, conditional on `mcpServer.enable`, same data dir pattern
- [ ] 3.4 Implement sync client systemd timer + oneshot service — `docker exec` into Hermes container, configurable `interval` (default 10min), `container` and `user` params, independent per `syncClients.<name>`
- [ ] 3.5 Implement Caddy proxy integration — emit `server.proxy.virtualHosts` for sync domain and optional MCP domain when `caddy.enable = true`, guarded by `config.server ? proxy` to avoid eval errors on hosts without server module
- [ ] 3.6 Verify module builds: `nix build .#nixosConfigurations.nixai.config.system.build.toplevel` (with mnemosyne disabled by default, no breakage)

## 4. NixAI host configuration

- [ ] 4.1 Create `hosts/server/nixai/mnemosyne.nix` — enable sync server on 127.0.0.1:8765, optional MCP on :8766, Caddy proxy for `sync.racci.dev` and optionally `mnemosyne-mcp.racci.dev`, Hermes sync client at 10min interval
- [ ] 4.2 Import `./mnemosyne.nix` in `hosts/server/nixai/default.nix`

## 5. NixOS integration test

- [ ] 5.1 Create NixOS test in `tests/nixos/mnemosyne-sync.nix` — spawn VM with sync server, run client sync, verify DB convergence (start sync server, create memory via `mnemosyne add`, run `mnemosyne sync --remote`, verify entry appears on client DB)

## 6. Documentation

- [ ] 6.1 Create `docs/src/modules/nixos/ai/overview.md` — module tree overview, relationship to existing `services.ai-agent`, what belongs in `ai/` vs `services/`
- [ ] 6.2 Create `docs/src/modules/nixos/ai/mnemosyne.md` — full option reference, sync/MCP architecture diagrams, usage examples (server-only, client-only, full stack with Caddy)
- [ ] 6.3 Update `docs/src/SUMMARY.md` — add AI Modules section with overview and mnemosyne entries

## 7. Final verification

- [ ] 7.1 Run `nix fmt .`
- [ ] 7.2 Run `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"`
- [ ] 7.3 Build affected configurations: `nix build .#nixosConfigurations.nixai.config.system.build.toplevel`
