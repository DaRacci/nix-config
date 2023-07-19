{ pkgs, ... }:
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
in
{

  imports = [
    ./hardware.nix

    ../common/optional/gnome.nix
    ../common/optional/hyprland.nix

    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gaming.nix
    ../common/optional/waydroid.nix
    # ../../containers
  ];

  boot.kernelPackages = pkgs.linuxPackages_xanmod_stable;

  services.teamviewer.enable = true;
  programs.sniffnet.enable = true;

  networking = {
    interfaces.enp5so = mkNetwork "eth0";
    interfaces.enp6so = mkNetwork "eth1";

    firewall = {
      allowedTCPPorts = [ 9999 ];
      allowedUDPPortRanges = [
        # KDE Connect
        { from = 1714; to = 1764; }
      ];
      allowedTCPPortRanges = [
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
}
