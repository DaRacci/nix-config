## Huntress

Managed EDR (Endpoint Detection and Response) platform that protects systems by detecting malicious footholds used by attackers.

- **Entry point**: `modules/nixos/services/huntress.nix`
- **Upstream**: [Huntress Managed EDR](https://www.huntress.com/platform/managed-edr)

### Options

{{#include ../../../generated/huntress-options.md}}

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

### Operational Notes

The agent configuration is generated at `/etc/huntress/agent_config.yaml` during the service's `preStart` phase. It merges the provided account and organisation keys using `yaml-merge`. The keys are securely loaded into the service using systemd `LoadCredential`.
