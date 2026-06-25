# Mnemosyne

SQLite-backed memory provider with sync and optional MCP server. Part of the `ai/` module tree.

## Architecture

```mermaid
graph TB
    subgraph "NixAI Host"
        HC["Hermes Container<br/>(mnemosyne-hermes plugin)"]
        SS["Sync Server<br/>(mnemosyne sync serve)"]
        MS["MCP Server<br/>(mnemosyne mcp --sse)"]
        CD["Caddy Proxy"]
        CT["systemd Timer<br/>(sync client)"]
    end

    subgraph "External"
        EXT["External MCP Clients<br/>(Cursor, Claude Code)"]
        REMOTE["Remote Mnemosyne<br/>(laptop, other host)"]
    end

    HC -->|"plugin reads/writes"| DB[(mnemosyne.db<br/>in container)]
    CT -->|"mnemosyne sync --remote"| SS
    SS -->|"serve"| SDB[(mnemosyne.db<br/>/var/lib/mnemosyne)]
    MS -->|"mcp"| SDB
    CD -->|"reverse_proxy"| SS
    CD -->|"reverse_proxy"| MS
    EXT -->|"MCP/SSE"| CD
    REMOTE -->|"sync protocol"| CD
```

## Options

{{#include ../../../../generated/ai-services-mnemosyne-options.md}}

## Usage Examples

### Server-only (central sync)

```nix
{
  ai.enable = true;
  services.mnemosyne = {
    enable = true;
    syncServer.enable = true;
  };
}
```

### Client-only (sync to remote)

```nix
{
  ai.enable = true;
  services.mnemosyne = {
    enable = true;
    syncClients.hermes = {
      remote = "http://sync.example.com:8765";
      interval = "15min";
    };
  };
}
```

### Full stack with Caddy

```nix
{
  ai.enable = true;
  services.mnemosyne = {
    enable = true;
    syncServer = {
      enable = true;
      host = "127.0.0.1";
      port = 8765;
    };
    mcpServer = {
      enable = true;
      host = "127.0.0.1";
      port = 8766;
    };
    syncClients.hermes = {
      remote = "http://127.0.0.1:8765";
      interval = "10min";
    };
    caddy = {
      enable = true;
      syncSubdomain = "sync";
      mcpSubdomain = "mnemosyne-mcp";
    };
  };
}
```

## Notes

- Sync server uses `mnemosyne sync serve` with stdlib HTTP — no extra Python dependencies.
- MCP server adds `mcp` and `anyio` dependencies (via `pkgs.mnemosyne-mcp`).
- Sync protocol is plain HTTP with delta-based bidirectional sync.
- Sync interval default is 10 minutes.
- `syncSubdomain` and `mcpSubdomain` are subdomain names only. The full domain is formed as `<subdomain>.<server.proxy.domain>` via the Caddy reverse proxy integration.
