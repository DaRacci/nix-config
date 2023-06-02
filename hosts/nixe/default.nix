{ ... }: {
  imports = [ 
    ./hardware-configuration.nix
    
    ../common/global
    ../common/users/racci

    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gaming.nix
  ];

  networking = {
    hostName = "nixe";
    useDHCP = true;
    enableIPv6 = false; #? TODO :: Learn IPv6 

    nameservers = [ "1.1.1.1" "1.0.0.1" ];

    interfaces.enp6s0 = {
      ipv4 = {
        addresses = [
          ## Aus Network
          {
            address = "192.168.2.156";
            prefixLength = 24;
          }
          ## USA Network
          {
            address = "10.0.0.2";
            prefixLength = 24;
          }
        ];
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "22.11";
}