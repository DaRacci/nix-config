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
  services.mnemosyne = {
    enable = true;
    server.sync.enable = true;
  };
}
```

### Client-only (sync to remote)

```nix
{
  services.mnemosyne = {
    enable = true;
    client.sync.hermes = {
      enable = true;
      remote = "http://sync.example.com:8765";
      interval = "*:0/15";
    };
  };
}
```

## Notes

- Sync server uses `mnemosyne sync serve` with stdlib HTTP — no extra Python dependencies.
- MCP server adds `mcp` and `anyio` dependencies (via `pkgs.mnemosyne-mcp`).
- Sync protocol is plain HTTP with delta-based bidirectional sync.
- Sync interval default is 10 minutes.
