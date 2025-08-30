# TODO - Authentik to unify login across services
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
        (builtins.map (host: host.config))
        # Filter to only servers
        (builtins.filter (config: config.host.device.role == "server"))
      ]
      ++ pipe
    );

  importFile = path: import path { inherit fromAllServers; };
in
{
  imports = [
    "${self}/hosts/shared/optional/tailscale.nix"

    ./tunnel
    ./adguard.nix
    ./dashboard.nix

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

  server.network.subnets = [
    {
      dns = "100.100.100.100:53";
      domain = "degu-beta.ts.net";
      ipv4 = {
        cidr = "100.64.0.0/10";
        arpa = "64.100.in-addr.arpa";
      };
      ipv6 = {
        cidr = "fd7a:115c:a1e0::/48";
        arpa = "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.e.1.a.c.5.1.1.a.7.d.f.ip6.arpa";
      };
    }
    {
      dns = "192.168.1.1:53";
      domain = "home";
      ipv4 = {
        cidr = "192.168.1.0/24";
        arpa = "1.168.192.in-addr.arpa";
      };
    }
    {
      dns = "192.168.2.1:53";
      domain = "localdomain";
      ipv4 = {
        cidr = "192.168.2.0/24";
        arpa = "2.168.192.in-addr.arpa";
      };
    }
  ];
}
