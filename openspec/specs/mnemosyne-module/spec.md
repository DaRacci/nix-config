# mnemosyne-module Specification

## Purpose
TBD - created by archiving change ai-module-tree. Update Purpose after archive.
## Requirements
### Requirement: Mnemosyne NixOS service

The system SHALL provide a `services.mnemosyne` NixOS module that manages Mnemosyne lifecycle, including sync server, optional MCP server, and sync client profiles.

#### Scenario: Module is importable

- **GIVEN** the `modules/nixos/ai/` tree is included in module imports
- **WHEN** `services.mnemosyne.enable = true` is set
- **THEN** the mnemosyne module options are available and configurable

#### Scenario: Module disabled by default

- **GIVEN** no `services.mnemosyne` configuration
- **WHEN** the system is evaluated
- **THEN** no Mnemosyne services, timers, or packages are activated

### Requirement: Sync server

The system SHALL run `mnemosyne sync serve` as a systemd service when `services.mnemosyne.syncServer.enable = true`.

#### Scenario: Sync server starts and binds

- **GIVEN** `services.mnemosyne.syncServer.enable = true` with default port 8765
- **WHEN** the systemd service `mnemosyne-sync-server` starts
- **THEN** the sync server listens on `127.0.0.1:8765` and accepts sync protocol HTTP requests

#### Scenario: Sync server uses configured data directory

- **GIVEN** `services.mnemosyne.dataDir = "/custom/path"`
- **WHEN** the sync server starts
- **THEN** the SQLite database is created at `/custom/path/mnemosyne.db`

#### Scenario: Sync server does not install MCP dependencies

- **GIVEN** `services.mnemosyne.syncServer.enable = true` and `mcpServer.enable = false`
- **WHEN** the NixOS closure is built
- **THEN** `pkgs.mnemosyne-mcp` is NOT included in the system closure

### Requirement: Optional MCP server

The system SHALL run `mnemosyne mcp --transport sse` as a systemd service when `services.mnemosyne.mcpServer.enable = true`.

#### Scenario: MCP server starts with SSE transport

- **GIVEN** `services.mnemosyne.mcpServer.enable = true` with default port 8766
- **WHEN** the systemd service `mnemosyne-mcp-server` starts
- **THEN** the MCP server listens on `127.0.0.1:8766` and serves SSE endpoints

#### Scenario: MCP server requires mcp-extras package

- **GIVEN** `services.mnemosyne.mcpServer.enable = true`
- **WHEN** the NixOS closure is built
- **THEN** `pkgs.mnemosyne-mcp` IS included in the system closure

### Requirement: Sync client via systemd timer

The system SHALL provide a configurable sync client per profile under `services.mnemosyne.syncClients.<name>`, executed via systemd `.timer` unit.

#### Scenario: Sync client runs on schedule

- **GIVEN** a sync client profile with `remote = "http://sync-server:8765"` and `interval = "10min"`
- **WHEN** the systemd timer `mnemosyne-sync-client-<name>` triggers
- **THEN** the one-shot service runs `mnemosyne sync --remote http://sync-server:8765` and exits

#### Scenario: Sync client uses container environment

- **GIVEN** a sync client profile with `container = "hermes-agent"` and `user = "hermes"`
- **WHEN** the sync client service runs
- **THEN** the command executes via `docker exec -u hermes hermes-agent mnemosyne sync --remote <url>`

#### Scenario: Multiple sync client profiles

- **GIVEN** two sync client profiles `primary` and `backup` with different remotes
- **WHEN** the system is evaluated
- **THEN** two separate `.timer` and `.service` units are generated

### Requirement: Caddy reverse proxy integration

The system SHALL integrate with the `server.proxy` module to expose sync and MCP servers with virtual host configuration, guarded behind option existence since the `ai/` module tree is independent of the server module tree.

#### Scenario: Sync server exposed via proxy

- **GIVEN** `services.mnemosyne.caddy.enable = true`, `caddy.syncDomain = "sync.example.com"`, and `config.server.proxy` exists
- **WHEN** the system is evaluated
- **THEN** a `server.proxy.virtualHosts` entry routes `sync.example.com` to the sync server port

#### Scenario: MCP server exposed via proxy

- **GIVEN** `services.mnemosyne.caddy.enable = true`, `caddy.mcpDomain = "mcp.example.com"`, and `config.server.proxy` exists
- **WHEN** the system is evaluated
- **THEN** a `server.proxy.virtualHosts` entry routes `mcp.example.com` to the MCP server port

#### Scenario: Caddy enabled but server.proxy not available

- **GIVEN** `services.mnemosyne.caddy.enable = true` on a host without `server.proxy` options imported
- **WHEN** the system is evaluated
- **THEN** evaluation succeeds without error; proxy config is silently skipped

### Requirement: Independent service enable/disable

Each sub-component (syncServer, mcpServer, each syncClient) SHALL be independently toggleable.

#### Scenario: Sync server enabled, MCP disabled

- **GIVEN** `services.mnemosyne.syncServer.enable = true` and `mcpServer.enable = false`
- **WHEN** the system is activated
- **THEN** only `mnemosyne-sync-server.service` runs; MCP server is not started

#### Scenario: Sync client without local server

- **GIVEN** a sync client pointing to a remote URL with `syncServer.enable = false`
- **WHEN** the system is activated
- **THEN** the timer runs the client sync command; no local sync server is started

