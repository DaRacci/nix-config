{ ... }: {

  imports = [
    ./hardware.nix

    ../common/optional/containers.nix
    ../common/optional/virtualisation.nix

    ../common/optional/gnome.nix
    ../common/optional/hyprland.nix

    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gaming.nix
    ../common/optional/tailscale.nix
  ];

  programs.nix-ld.enable = true;

  host = {
    drive = {
      enable = true;

      format = "btrfs";
      name = "Nix";
    };

    persistence = {
      enable = true;
      type = "tmpfs";

      directories = [
        "/var/lib/ollama"
      ];
    };
  };

  networking = {
    firewall = {
      allowedUDPPorts = [ 9944 8082 9942 9943 ];
      allowedTCPPorts = [ 9999 22 5990 9944 8082 9942 9943 ];
    };
  };

  services.netdata = {
    enable = true;
  };

  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };

  # programs.adb.enable = true;
  # services.udev = {
  #   enable = true;
  #   extraRules = ''
  #     SUBSYSTEM="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0186", MODE="0660", GROUP="plugdev", symlink+="ocuquest%n"
  #   '';
  # };
}
