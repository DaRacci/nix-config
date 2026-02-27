# Server Network Module

The Server Network module provides a declarative way to manage network configurations and firewall rules across the server cluster.

## Purpose

The network module coordinates network subnet definitions and firewall rules, allowing for centralized configuration of subnets and automatic propagation of these settings to other servers in the cluster.

## Entry Point

- `modules/nixos/server/network.nix`

## Special Options and Behaviors

The main configuration options are under `server.network`:

- **`server.network.subnets`**: A list of subnet definitions, each with:
  - `dns`: The DNS server for the subnet.
  - `domain`: The domain name for the subnet.
  - `ipv4`, `ipv6`: Configuration options (like CIDR and ARPA) for the subnet's IP range.
- **`server.network.openPortsForSubnet`**: Defines TCP and UDP ports to be opened on the firewall for each defined subnet.

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
