# Server Network Module

The Server Network module provides a declarative way to manage network configurations and firewall rules across the server cluster.

## Purpose

The network module coordinates network subnet definitions and firewall rules, allowing for centralized configuration of subnets and automatic propagation of these settings to other servers in the cluster.

## Entry Point

- `modules/nixos/server/network.nix`

## Options

{{#include ../../../../generated/server-network-options.md}}

## Example Usage

Configure a subnet and open ports on a server:

```nix
# hosts/server/nixio/default.nix
{
  server.network = {
    subnets = [
      {
        dns = "192.168.1.1";
        domain = "lan.example.com";
        ipv4.cidr = "192.168.1.0/24";
      }
    ];
    openPortsForSubnet = {
      tcp = [ 80 443 ];
    };
  };
}
```

## Operational Notes

- This module uses `getIOPrimaryHostAttr` to fetch the `server.network.subnets` configuration from the `ioPrimaryHost`.
- This ensures that all servers in the cluster are aware of the network structure defined on the coordinator host.
- The module automatically generates `iptables` and `ip6tables` rules for the specified ports, allowing traffic only from the defined subnets.
- These rules are added to the `nixos-fw` chain and are managed through the `networking.firewall.extraCommands` and `networking.firewall.extraStopCommands` options.
