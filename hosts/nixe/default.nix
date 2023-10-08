{ ... }: {

  imports = [
    ./hardware.nix

    ../common/optional/impermanence.nix
    ../common/optional/containers.nix
    ../common/optional/virtualisation.nix

    ../common/optional/gnome.nix
    # ../common/optional/hyprland.nix

    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gaming.nix
    # ../../containers
  ];

  services.teamviewer.enable = true;
  services.ratbagd.enable = true;

  networking = {
    firewall = {
      allowedTCPPorts = [ 9999 22 ];
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
}
