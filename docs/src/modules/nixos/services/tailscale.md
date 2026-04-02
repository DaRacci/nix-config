## Tailscale

Extensions to the standard NixOS Tailscale module, providing easier tag management.

- **Entry point**: `modules/nixos/services/tailscale.nix`
- **Upstream**: [Tailscale Tags Documentation](https://tailscale.com/kb/1018/tags/)

### Special Options

- `services.tailscale.tags`: A list of tags to advertise for this device. These tags are automatically prefixed with `tag:` when passed to `tailscale up`.

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
