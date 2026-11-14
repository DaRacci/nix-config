{
  self,
  config,
  lib,
  ...
}:
let
  fromAllServers =
    pipe:
    lib.trivial.pipe self.nixosConfigurations (
      [
        # Exclude the current host
        (lib.filterAttrs (name: _: name != config.system.name))
        # Extract the config from each host
        builtins.attrValues
        (map (host: host.config))
        # Filter to only servers
        (builtins.filter (config: config.host.device.role == "server"))
      ]
      ++ pipe
    );

  importFile = path: import path { inherit fromAllServers; };
in
{
  imports = [
    ./tunnel
    ./adguard.nix
    ./dashboard.nix

    (importFile ./database.nix)
    (importFile ./proxy.nix)
    (importFile ./storage.nix)
  ];

  core = {
    networking.tailscale.enable = true;
  };

  server.dashboard = {
    name = "NixIO";
    icon = "hl-networking-toolbox";
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.tailscale = {
    tags = [ "ingress" ];
    extraSetFlags = [ "--advertise-routes=192.168.2.0/24" ];
  };
}
