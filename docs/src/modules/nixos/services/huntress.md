# Huntress — Managed EDR

## Purpose

Managed EDR (Endpoint Detection and Response) platform that protects systems by detecting malicious footholds used by attackers.

## Entry Point

- **Main file**: [huntress.nix](../../../../../modules/nixos/services/huntress.nix)
- **Upstream**: [Huntress Managed EDR](https://www.huntress.com/platform/managed-edr)

#### Options

{{#include ../../../../generated/services-huntress-options.md}}

## Architecture / Services / Scope

The module runs a single `huntress-agent` systemd service as `root`. The agent configuration is generated at `/etc/huntress/agent_config.yaml` during the service's `preStart` phase: a default configuration is written on first start, after which the account and organisation keys are merged in using `yaml-merge`.

## Secrets

- `accountKeyFile` — Huntress account key, loaded into the service via systemd `LoadCredential`.
- `organisationKeyFile` — Huntress organisation key, loaded into the service via systemd `LoadCredential`.

## Operational Notes / Assumptions

- Both keys are validated during `preStart`; the service fails to start if either is empty.
- The merged configuration persists across restarts in `/etc/huntress/agent_config.yaml`.

### Usage Example

```nix
{ config, ... }: {
  services.huntress = {
    enable = true;
    accountKeyFile = config.sops.secrets.huntress_account_key.path;
    organisationKeyFile = config.sops.secrets.huntress_org_key.path;
  };
}
```

## References

- [Huntress Managed EDR](https://www.huntress.com/platform/managed-edr)
