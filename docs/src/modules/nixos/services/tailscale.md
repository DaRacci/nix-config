## Tailscale

Extensions to the standard NixOS Tailscale module, providing easier tag management.

- **Entry point**: `modules/nixos/services/tailscale.nix`

### Options

{{#include ../../../../generated/services-tailscale-options.md}}

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
