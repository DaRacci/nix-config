# Server Distributed Builds Module

The Server Distributed Builds module provides a declarative way to manage distributed builds across the server cluster.

## Purpose

The distributed builds module allows for distributed building of Nix derivations using remote build machines, providing a coordinator host and several build machines to distribute the build load.

## Entry Point

- `modules/nixos/server/distributed-builds.nix`

## Special Options and Behaviors

The module provides options under `server.distributedBuilder`:

- **`server.distributedBuilder.builderUser`**: The user to use when connecting to remote build daemons (default: `builder`).
- **`server.distributedBuilder.builders`**: A list of hostnames of remote build daemons to connect to for distributed builds.

## Example Usage

Configure a build server and a host to use it for distributed builds:

```nix
# hosts/server/nixserv/default.nix (build server)
{
  server.distributedBuilder = {
    builders = [ "nixserv" ];
  };
}

# hosts/server/nixdev/default.nix (host using build server)
{
  server.distributedBuilder = {
    builders = [ "nixserv" ];
  };
}
```

## Operational Notes

- This module coordinates the creation of a system user (`builder`) on the build server and adds the necessary SSH keys to allow other hosts to connect.
- On the hosts using the build server, the module automatically configures `nix.distributedBuilds` and sets up the build machines using `nix.buildMachines`.
- The `builder` user is automatically added to `nix.settings.trusted-users` on the build server.
- The module uses `self.nixosConfigurations` to dynamically discover the system architecture of the build machines.
- For more information on distributed builds in Nix, see the [NixOS Manual](https://nixos.org/manual/nixos/stable/index.html#sec-distributed-builds).
