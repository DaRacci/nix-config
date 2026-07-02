# MCPO — Model Context Protocol Orchestrator

## Purpose

Orchestrates Model Context Protocol (MCP) servers, providing a centralized way to manage and expose multiple MCP servers.

## Entry Point

- **Main file**: [mcpo.nix](../../../../../modules/nixos/services/mcpo.nix)
- **Upstream**: [MCPO GitHub Repository](https://github.com/open-webui/mcpo)

#### Options

{{#include ../../../../generated/services-mcpo-options.md}}

## Architecture / Services / Scope

MCPO runs as a `DynamicUser` with a state directory at `/var/lib/mcpo`. The configuration is rendered via `sops.templates` and loaded into the service via systemd credentials. The service's `PATH` includes `bash`, `nodejs`, and `uv` by default to support various MCP server types; additional packages can be added with `services.mcpo.extraPackages`.

## Secrets

- `apiTokenFile` (optional) — API token exposed to the service as the systemd credential `apiToken`.
- Server configuration and environment are rendered through sops templates (`mcpoConfiguration`, `mcpoEnvironment`) and consumed via `LoadCredential` / `EnvironmentFile`.

## Operational Notes / Assumptions

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

### Package Patches

- **mcpo-union-repr-compat.patch** — Applied via overlay in `overlays/patches/`. Upstream test `src/mcpo/tests/test_main.py` asserts `Union` repr starts with `"typing.Union["`, but Python 3.12+ may stringify unions as `str | float`. Patch uses `get_origin(result_type) is Union` instead. Build/test compatibility only; no runtime impact.

## References

- [MCPO GitHub Repository](https://github.com/open-webui/mcpo)
