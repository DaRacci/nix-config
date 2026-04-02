## MCPO (Model Context Protocol Orchestrator)

Orchestrates Model Context Protocol (MCP) servers, providing a centralized way to manage and expose multiple MCP servers.

- **Entry point**: `modules/nixos/services/mcpo.nix`
- **Upstream**: [MCPO GitHub Repository](https://github.com/open-webui/mcpo)

### Special Options

- `services.mcpo.configuration`: An attribute set defining the MCP servers to orchestrate.
- `services.mcpo.apiTokenFile`: Optional path to a file containing an API token for the service.
- `services.mcpo.extraPackages`: Additional packages to include in the service's `PATH`.
- `services.mcpo.helpers`: Read-only attribute set of helper functions for common server types (e.g., `npxServer`, `uvxServer`).

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
