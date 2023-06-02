{ pkgs, inputs, ...}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-hidpi
    
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
    tcpcrypt.enable = true;
    enableIPv6 = false; #? TODO :: Learn IPv6 

    nameservers = [ "1.1.1.1" "1.0.0.1" ];

    interfaces.enp6s0 = {
      ipv4 = {
        addresses = [
          ## Aus Network
          {
            address = "192.168.2.156";
            prefixLength = 24;
            via = "192.168.2.1";
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