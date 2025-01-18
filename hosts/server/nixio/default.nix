{ flake, config, modulesPath, lib, ... }:
let
  subnets = [
    {
      dns = "100.100.100.100:53";
      ipv4_cidr = "100.64.0.0/10";
      ipv4_arpa = "64.100.in-addr.arpa";
      ipv6_cidr = "fd7a:115c:a1e0::/48";
      ipv6_arpa = "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.0.0.0.0.f.7.2.0.0.2.ip6.arpa";
      domain = "degu-beta.ts.net";
    }
    {
      dns = "192.168.1.1:53";
      ipv4_cidr = "192.168.1.0/24";
      ipv4_arpa = "1.168.192.in-addr.arpa";
      ipv6_cidr = null;
      ipv6_arpa = null;
      domain = "home";
    }
    {
      dns = "192.168.2.1:53";
      ipv4_cidr = "192.168.2.0/24";
      ipv4_arpa = "2.168.192.in-addr.arpa";
      ipv6_cidr = null;
      ipv6_arpa = null;
      domain = "localdomain";
    }
  ];

  fromAllServers = pipe: lib.trivial.pipe flake.nixosConfigurations ([
    # Exclude the current host
    (lib.filterAttrs (name: _: name != config.system.name))
    # Extract the config from each host
    builtins.attrValues
    (builtins.map (host: host.config))
    # Filter to only servers
    (builtins.filter (config: config.host.device.role == "server"))
  ] ++ pipe);

  mkVirtualHost = name: config: lib.nameValuePair "${name}.racci.dev" ({
    hostName = "${name}.racci.dev";
    useACMEHost = "${name}.racci.dev";
  } // config);

  importFile = path: import path { inherit subnets fromAllServers mkVirtualHost; };
in
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    (importFile ./adguard.nix)
    (importFile ./database.nix)
    (importFile ./proxy.nix)
    (importFile ./storage.nix)
  ];

  #region Site2Site VPN
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.tailscale = { };
  #endregion
}
