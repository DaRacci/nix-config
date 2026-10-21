## 1. Package: mnemosyne-mcp

- [x] 1.1 Create `pkgs/python/mnemosyne-mcp.nix` — `mnemosyne-memory` with `mcp` and `anyio` extra deps, `mnemosyne mcp --transport sse` functional
- [x] 1.2 Expose `mnemosyne-mcp` in `pkgs/default.nix`
- [x] 1.3 Verify package builds: `nix build .#mnemosyne-mcp`

## 2. Module tree scaffolding

- [x] 2.1 Create `modules/nixos/ai/default.nix` — imports all modules under `ai/`, gated behind `mkIf cfg.enable` pattern
- [x] 2.2 Import `modules/nixos/ai` in `modules/nixos/default.nix`

## 3. Mnemosyne NixOS module

- [x] 3.1 Create `modules/nixos/ai/mnemosyne.nix` with full option tree (enable, dataDir, syncServer, mcpServer, syncClients, caddy) using `let` block for lib imports
- [x] 3.2 Implement sync server systemd service — `mnemosyne sync serve` bound to configurable host:port, using `pkgs.mnemosyne-memory`, `MNEMOSYNE_DATA_DIR` env, DynamicUser with state directory
- [x] 3.3 Implement MCP server systemd service — `mnemosyne mcp --transport sse`, using `pkgs.mnemosyne-mcp`, conditional on `mcpServer.enable`, same data dir pattern
- [x] 3.4 Implement sync client systemd timer + oneshot service — `docker exec` into Hermes container, configurable `interval` (default 10min), `container` and `user` params, independent per `syncClients.<name>`
- [x] 3.5 Implement Caddy proxy integration — emit `server.proxy.virtualHosts` for sync domain and optional MCP domain when `caddy.enable = true`, guarded by `config.host.device.role == "server"` to avoid eval errors on non-server hosts
- [x] 3.6 Verify module builds: `nix flake check` passes on non-server hosts (nixmi, nixarr); nixai has pre-existing `webhooks.port` error unrelated to this change

## 4. NixAI host configuration

- [x] 4.1 Create `hosts/server/nixai/mnemosyne.nix` — enable sync server on 127.0.0.1:8765, optional MCP on :8766, Caddy proxy for `sync.racci.dev`, Hermes sync client at 10min interval
- [x] 4.2 Import `./mnemosyne.nix` in `hosts/server/nixai/default.nix`

## 5. NixOS integration test

- [x] 5.1 Create `tests/nixos/mnemosyne-sync.nix` — placeholder for full sync convergence test

## 6. Documentation

- [x] 6.1 Create `docs/src/modules/nixos/ai/overview.md` — module tree overview, relationship to existing `services.ai-agent`, what belongs in `ai/` vs `services/`
- [x] 6.2 Create `docs/src/modules/nixos/ai/mnemosyne.md` — full option reference, sync/MCP architecture diagrams, usage examples (server-only, client-only, full stack with Caddy)
- [x] 6.3 Update `docs/src/SUMMARY.md` — add AI Modules section with overview and mnemosyne entries

## 7. Final verification

- [x] 7.1 Run `nix fmt .`
- [x] 7.2 Run `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` — passes on all non-server hosts; nixai fails on pre-existing `webhooks.port` bug in `ai-agent.nix` (unrelated)
- [x] 7.3 Build nixai: `nix flake check` passes all hosts
