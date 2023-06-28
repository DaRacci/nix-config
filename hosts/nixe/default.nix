{ inputs, pkgs, ... }:

let
  IPv4-Australia = "192.168.2.156";
  IPv4-USA = "10.0.0.2";

  mkNetwork = interfaceName: {
    useDHCP = false;
    name = interfaceName;
  	ipv4 = {
  		addresses = [
  			{ address = "${IPv4-Australia}"; prefixLength = 24; }
  			{ address = "${IPv4-USA}"; prefixLength = 24; }
  		];
  	};
  };
in {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    ./hardware-configuration.nix
    
    ../common/global
    ../common/users/racci

    ../common/optional/gnome.nix
    ../common/optional/hyprland.nix

    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gaming.nix
    ../common/optional/waydroid.nix
    ../../containers
  ];

  networking = {
    hostName = "nixe";
    # useDHCP = true;
    enableIPv6 = false; #? TODO :: Learn IPv6 

    nameservers = [ "1.1.1.1" "1.0.0.1" ];

    interfaces.enp5so = mkNetwork "eth0";
    interfaces.enp6so = mkNetwork "eth1";

    firewall = {
      allowedTCPPorts = [ 9999 ];
      allowedUDPPortRanges = [
        # KDE Connect
        { from = 1714; to = 1764; }
      ];
    };
  };

  # services.autorandr = {
  #   enable = true;
  #   profiles = {
  #     AUS = {
  #       fingerprint = {

  #       };
  #       config = {

  #       };
  #     }
  #   }
  # }

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "22.11";
}
