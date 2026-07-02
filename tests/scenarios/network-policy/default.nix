{ ... }: {
  imports = [
    (import ../../../modules/nixos/server/network.nix {
      isThisIOPrimaryHost = true;
      getIOPrimaryHostAttr = _: [ ];
    })
  ];

  server.network = {
    subnets = [
      {
        dns = "10.0.1.2";
        domain = "subnet-a.internal";
        ipv4 = {
          cidr = "10.0.1.0/24";
        };
        ipv6 = {
          cidr = "fd00:a:1::/64";
        };
      }
      {
        dns = "10.0.2.2";
        domain = "subnet-b.internal";
        ipv4 = {
          cidr = "10.0.2.0/24";
        };
        ipv6 = {
          cidr = "fd00:a:2::/64";
        };
      }
    ];

    openPortsForSubnet = {
      tcp = [
        5432
        8080
      ];
      udp = [
        51820
        53
      ];
    };
  };

  networking.firewall.enable = true;
  services.openssh.enable = true;
}
