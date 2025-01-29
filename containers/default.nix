{ inputs, ... }:
{
  imports = [ inputs.arion.nixosModules.arion ];

  virtualisation.arion = {
    backend = "docker";
    projects = {
      global.settings = {
        enableDefaultNetwork = false;
        networks.outside = {
          name = "outside";
          internal = false;
          attachable = false;
          enable_ipv6 = false; # TODO :: Learn IPv6
          ipam.config = [
            {
              subnet = "10.10.9.0/24";
              ip_range = "10.10.9.0/24";
              gateway = "10.10.9.1";
            }
          ];
        };
      };
    };
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "eth0";
    enableIPv6 = false;
  };
}
