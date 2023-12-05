{ ... }: {

  imports = [
    ./hardware.nix

    ../common/optional/containers.nix
    ../common/optional/virtualisation.nix

    ../common/optional/gnome.nix
    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gaming.nix
  ];

  services.teamviewer.enable = true;
  services.ratbagd.enable = true;
  programs.nix-ld.enable = true;

  host = {
    drive.format = "btrfs";

    persistence = {
      enable = true;
      type = "tmpfs";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  networking = {
    firewall = {
      allowedUDPPorts = [ 9944 8082 9942 9943 ];
      allowedTCPPorts = [ 9999 22 5990 9944 8082 9942 9943 ];
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

  programs.adb.enable = true;
  services.udev = {
    enable = true;
    extraRules = ''
      SUBSYSTEM="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0186", MODE="0660", GROUP="plugdev", symlink+="ocuquest%n"
    '';
  };
}
