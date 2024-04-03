{ flake, ... }: {

  imports = [
    ./hardware.nix

    "${flake}/hosts/shared/optional/containers.nix"
    "${flake}/hosts/shared/optional/virtualisation.nix"

    "${flake}/hosts/shared/optional/gnome.nix"
    "${flake}/hosts/shared/optional/hyprland.nix"

    "${flake}/hosts/shared/optional/pipewire.nix"
    "${flake}/hosts/shared/optional/quietboot.nix"
    "${flake}/hosts/shared/optional/gaming.nix"
    "${flake}/hosts/shared/optional/tailscale.nix"
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
        "/var/lib/private/ollama"
      ];
    };
  };

  networking = {
    firewall = {
      allowedUDPPorts = [ 9944 8082 9942 9943 ];
      allowedTCPPorts = [ 9999 22 5990 9944 8082 9942 9943 8080 ];
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
