## Tailscale

Extensions to the standard NixOS Tailscale module, providing easier tag management.

- **Entry point**: `modules/nixos/services/tailscale.nix`
- **Upstream**: [Tailscale Tags Documentation](https://tailscale.com/kb/1018/tags/)

### Options

{{#include ../../../generated/tailscale-options.md}}

> **Tip:** You can also browse these options in the full
> [RacciDev Options Search](../../../search/index.html?query=services.tailscale)
> for richer filtering and cross-module comparison.

### Usage Example

```nix
{ ... }: {
  services.tailscale = {
    enable = true;
    tags = [ "server" "internal" ];
  };
}
```

### Operational Notes

This module simplifies the application of Tailscale tags by automatically constructing the `--advertise-tags` flag. Ensure that the device has the necessary permissions in your Tailscale ACLs to apply the requested tags.
