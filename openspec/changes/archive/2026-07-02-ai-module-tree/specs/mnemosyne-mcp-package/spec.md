## ADDED Requirements

### Requirement: Mnemosyne MCP package

The system SHALL provide `pkgs.mnemosyne-mcp`, a Python package that includes `mnemosyne-memory` with the `[mcp]` extras for running the MCP server.

#### Scenario: Package builds successfully

- **GIVEN** the package definition at `pkgs/python/mnemosyne-mcp.nix`
- **WHEN** `nix build .#mnemosyne-mcp` is invoked
- **THEN** the package builds and produces a Python environment with `mnemosyne` CLI

#### Scenario: Package includes mcp and anyio dependencies

- **GIVEN** the built `mnemosyne-mcp` package
- **WHEN** `python -c "import mcp; import anyio"` is run inside the package environment
- **THEN** both `mcp` and `anyio` modules import successfully

#### Scenario: Package can start MCP server in SSE mode

- **GIVEN** `pkgs.mnemosyne-mcp` is available
- **WHEN** `mnemosyne mcp --transport sse --host 127.0.0.1 --port 18765` is started
- **THEN** the server binds to the given port and responds to HTTP health check within 3 seconds

#### Scenario: Package is distinct from base mnemosyne-memory

- **GIVEN** both `pkgs.mnemosyne-memory` and `pkgs.mnemosyne-mcp` are available
- **WHEN** using `pkgs.mnemosyne-memory`
- **THEN** the `mcp` and `anyio` Python modules are NOT importable (unless already in python environment)

#### Scenario: Package depends on mnemosyne-memory

- **GIVEN** the `mnemosyne-mcp` package definition
- **WHEN** the package is evaluated
- **THEN** `mnemosyne-memory` is listed as a build or runtime dependency
