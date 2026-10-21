# Tailscale — Tag Management Extensions

## Purpose

Extensions to the standard NixOS Tailscale module, providing easier tag management.

## Entry Point

- **Main file**: [tailscale.nix](../../../../../modules/nixos/services/tailscale.nix)

#### Options

{{#include ../../../../generated/services-tailscale-options.md}}

## Architecture / Services / Scope

This module extends the standard NixOS `services.tailscale` module by automatically constructing the `--advertise-tags` flag from the configured `services.tailscale.tags` list.

## Operational Notes / Assumptions

- Ensure the device has the necessary permissions in your Tailscale ACLs to apply the requested tags.

### Usage Example

```nix
{ ... }: {
  services.tailscale = {
    enable = true;
    tags = [ "server" "internal" ];
  };
}
```

## References

- [Tailscale Tags](https://tailscale.com/kb/1018/tags/)
