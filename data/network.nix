{
  self,
  lib,
  dataLib,
}:
let
  normalize =
    subnet:
    subnet
    // {
      ipv4 = {
        cidr = null;
        arpa = null;
      }
      // (subnet.ipv4 or { });
      ipv6 = {
        cidr = null;
        arpa = null;
      }
      // (subnet.ipv6 or { });
    };

  subnets = map normalize [
    {
      dns = "100.100.100.100:53";
      domain = "degu-beta.ts.net";
      ipv4 = {
        cidr = "100.64.0.0/10";
        arpa = "64.100.in-addr.arpa";
      };
      ipv6 = {
        cidr = "fd7a:115c:a1e0::/48";
        arpa = "0.e.1.a.c.5.1.1.a.7.d.f.ip6.arpa";
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
      ipv6 = {
        cidr = "fc01::/64";
        arpa = "0.0.0.0.0.0.0.0.0.0.0.0.1.0.c.f.ip6.arpa";
      };
    }
  ];

  ipv4Cidrs = builtins.filter (cidr: cidr != null) (map (subnet: subnet.ipv4.cidr) subnets);
  ipv6Cidrs = builtins.filter (cidr: cidr != null) (map (subnet: subnet.ipv6.cidr) subnets);

  clusterPrefix = "fd10:10:10:1";

  clusterIid =
    name:
    let
      hash = builtins.hashString "sha256" name;
    in
    "${builtins.substring 0 4 hash}:${builtins.substring 4 4 hash}:${builtins.substring 8 4 hash}:${builtins.substring 12 4 hash}";

  clusterHosts = (lib.builders.getHostsByType self).server;
  cluster = {
    vlan = 42;
    zone = "clusterzone";
    vnet = "cluster";
    domain = "cluster";
    prefixLength = 64;
    cidr = "${clusterPrefix}::/64";
    hosts = builtins.listToAttrs (
      map (name: {
        inherit name;
        value = "${clusterPrefix}:${clusterIid name}";
      }) clusterHosts
    );
  };

  ipKeys = [
    "cidr"
    "arpa"
  ];
in
{
  data = {
    inherit
      subnets
      ipv4Cidrs
      ipv6Cidrs
      cluster
      ;
    cidrs = ipv4Cidrs ++ ipv6Cidrs;
  };

  validate =
    lib: data:
    let
      subnets = data.network.subnets;
      domains = map (subnet: subnet.domain) subnets;
      cidrs = data.network.cidrs;
      cluster = data.network.cluster;
      clusterAddresses = builtins.attrValues cluster.hosts;
      duplicateClusterAddresses =
        clusterAddresses
        |> builtins.groupBy (address: address)
        |> lib.filterAttrs (_: addresses: builtins.length addresses > 1)
        |> builtins.attrNames;
    in
    dataLib.unique { values = domains; }
    ++ dataLib.unique { values = cidrs; }
    ++ builtins.concatMap (
      subnet:
      dataLib.keys {
        expected = [
          "dns"
          "domain"
          "ipv4"
          "ipv6"
        ];
        actual = builtins.attrNames subnet;
      }
      ++ dataLib.keys {
        expected = ipKeys;
        actual = builtins.attrNames subnet.ipv4;
      }
      ++ dataLib.keys {
        expected = ipKeys;
        actual = builtins.attrNames subnet.ipv6;
      }
    ) subnets
    ++ map (subnet: {
      assertion = subnet.ipv4.cidr != null || subnet.ipv6.cidr != null;
      message = "subnet ${subnet.domain or "unnamed"} has no CIDR";
    }) subnets
    ++ [
      {
        assertion = cluster.vlan >= 1 && cluster.vlan <= 4094;
        message = "cluster VLAN must be between 1 and 4094";
      }
      {
        assertion =
          builtins.match "[A-Za-z][A-Za-z0-9]*" cluster.vnet != null
          && builtins.stringLength cluster.vnet <= 8;
        message = "cluster VNet ID must be alphanumeric, start with a letter, and be at most 8 characters";
      }
      {
        assertion = cluster.hosts != { };
        message = "cluster hosts must not be empty";
      }
      {
        assertion = duplicateClusterAddresses == [ ];
        message = "duplicate cluster host addresses: ${toString duplicateClusterAddresses}";
      }
      {
        assertion = builtins.all (address: lib.hasPrefix "${clusterPrefix}:" address) clusterAddresses;
        message = "cluster host addresses must use the ${clusterPrefix}::/64 prefix";
      }
    ];
}
