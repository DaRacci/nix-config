## Why

Hermes Agent memory provider was migrated from ByteRover to Mnemosyne (SQLite-backed, zero-runtime-deps). But Mnemosyne has been bolted onto the monolithic `services.ai-agent` module via `extraPythonPackages` — no first-class NixOS module for its server modes (sync server, optional MCP server), no structured module tree for future AI services, and no sync client orchestration. This change establishes a proper `modules/nixos/ai/` tree with a dedicated Mnemosyne module, laying the groundwork for clean separation of AI infrastructure from the Hermes container config.

## What Changes

- Create **new module tree** `modules/nixos/ai/` as the canonical home for AI infrastructure services (not replacing `services.ai-agent` — that stays for Hermes-specific config)
- Add **`mnemosyne` NixOS module** with:
  - Sync server (stdlib HTTP, zero extra deps) for central Mnemosyne-to-Mnemosyne bidirectional delta sync
  - Optional MCP server (needs `mcp`+`anyio` deps) for external MCP clients (Cursor, Claude Code, Codex)
  - Cron-driven sync client profile inside Hermes container (periodic `mnemosyne sync --remote`)
  - Caddy reverse proxy integration for external access to sync/MCP servers
- Add **`python/mnemosyne-mcp` Nix package** for the MCP server extras variant
- Add **NixOS test** for Mnemosyne sync flow (start sync server, run client sync, verify DB convergence)
- Add **documentation** under `docs/src/modules/nixos/ai/`
- Expose Mnemosyne on **nixai** host: sync server on `sync.racci.dev`, optional MCP server, Hermes cron sync every 10 minutes

### Non-goals

- Do NOT replace or refactor `services.ai-agent` or `services.hermes-agent` — those remain as-is
- Do NOT add encryption (XChaCha20-Poly1305) to the sync module in this change (can be added later)
- Do NOT migrate other AI services (ollama, open-webui, mcpo) into the new tree — scope is Mnemosyne only

## Capabilities

### New Capabilities

- `mnemosyne-module`: NixOS module managing Mnemosyne sync server, optional MCP server, sync client profiles, and Caddy proxy integration
- `mnemosyne-mcp-package`: Nix Python package for `mnemosyne-memory[mcp]` (adds `mcp` + `anyio` Python dependencies)

### Modified Capabilities

<!-- None — no existing specs have requirement changes -->

## Impact

- **New files**: `modules/nixos/ai/default.nix`, `modules/nixos/ai/mnemosyne.nix`, `pkgs/python/mnemosyne-mcp.nix`, `docs/src/modules/nixos/ai/overview.md`, `docs/src/modules/nixos/ai/mnemosyne.md`, `docs/src/SUMMARY.md` (add AI section)
- **Modified files**: `modules/nixos/default.nix` (import new `ai/` tree), `pkgs/default.nix` (expose `mnemosyne-mcp`), `hosts/server/nixai/default.nix` (import mnemosyne config)
- **New host config**: `hosts/server/nixai/mnemosyne.nix` (sync server + client on nixai)
- **Dependencies**: `mnemosyne-mcp` will depend on `mnemosyne-memory` + `mcp` + `anyio` Python packages
- **Caddy virtualHosts**: `sync.racci.dev` (sync), optionally `mnemosyne-mcp.racci.dev` (MCP)
