## MCPO (Model Context Protocol Orchestrator)

Orchestrates Model Context Protocol (MCP) servers, providing a centralized way to manage and expose multiple MCP servers.

- **Entry point**: `modules/nixos/services/mcpo.nix`
- **Upstream**: [MCPO GitHub Repository](https://github.com/open-webui/mcpo)

### Options

{{#include ../../../generated/mcpo-options.md}}

### Usage Example

```nix
{ config, ... }: {
  services.mcpo = {
    enable = true;
    configuration = {
      everything = config.services.mcpo.helpers.npxServer "@modelcontextprotocol/server-everything";
    };
  };
}
```

### Operational Notes

MCPO runs as a `DynamicUser` with a state directory at `/var/lib/mcpo`. The configuration is rendered via `sops.templates` and loaded into the service via systemd credentials. The service's `PATH` includes `bash`, `nodejs`, and `uv` by default to support various MCP server types.
