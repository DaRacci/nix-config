# Firecrawl

Generic Firecrawl service wrapper with hardened systemd sandboxing.

- **Entry point**: `modules/nixos/services/firecrawl.nix`
- **Package**: `pkgs.firecrawl`

## Special Options

- `services.firecrawl.enable`: Enable Firecrawl.
- `services.firecrawl.package`: Override package providing Firecrawl binary.
- `services.firecrawl.host`: Bind address.
- `services.firecrawl.port`: Listen port.
- `services.firecrawl.openFirewall`: Open firewall for listen port.
- `services.firecrawl.apiKeyFile`: Optional secret file for self-hosted auth.
- `services.firecrawl.bullAuthKeyFile`: Optional secret file for queue admin UI auth.
- `services.firecrawl.environment`: Extra environment vars rendered via `sops.templates`.
- `services.firecrawl.extraArgs`: Extra args for service command.

## Secrets Management

Prefer sops-nix for API key handling. `nixai` wires secret `FIRECRAWL/API_KEY` into Firecrawl via systemd credential and `FIRECRAWL_API_KEY` env var.

## Usage Example

```nix
{ config, ... }: {
  sops.secrets."FIRECRAWL/API_KEY" = { };

  services.firecrawl = {
    enable = true;
    apiKeyFile = config.sops.secrets."FIRECRAWL/API_KEY".path;
    environment.FIRECRAWL_API_KEY = config.sops.placeholder."FIRECRAWL/API_KEY";
  };
}
```

## Operational Notes

Service runs as `DynamicUser` with strict sandboxing, state in `/var/lib/firecrawl`, and no public port unless `openFirewall` is set.

## Host Wiring

`nixai` enables Firecrawl with secrets `FIRECRAWL/API_KEY` and `FIRECRAWL/BULL_AUTH_KEY`, keeps it bound to `127.0.0.1`, and exposes it through `server.proxy.virtualHosts.firecrawl`.
