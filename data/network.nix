{ v }:
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
      ;
    cidrs = ipv4Cidrs ++ ipv6Cidrs;
  };

  validate =
    _lib: data:
    let
      subnets = data.network.subnets;
      domains = map (subnet: subnet.domain) subnets;
      cidrs = data.network.cidrs;
    in
    v.unique { values = domains; }
    ++ v.unique { values = cidrs; }
    ++ builtins.concatMap (
      subnet:
      v.keys {
        expected = [
          "dns"
          "domain"
          "ipv4"
          "ipv6"
        ];
        actual = builtins.attrNames subnet;
      }
      ++ v.keys {
        expected = ipKeys;
        actual = builtins.attrNames subnet.ipv4;
      }
      ++ v.keys {
        expected = ipKeys;
        actual = builtins.attrNames subnet.ipv6;
      }
    ) subnets
    ++ map (subnet: {
      assertion = subnet.ipv4.cidr != null || subnet.ipv6.cidr != null;
      message = "subnet ${subnet.domain or "unnamed"} has no CIDR";
    }) subnets;
}
