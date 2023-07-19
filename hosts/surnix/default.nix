{ ... }: {
  imports = [
    ./hardware.nix

    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gnome.nix
    ../common/optional/gaming.nix
  ];

  microsoft-surface.kernelVersion = "6.1.18";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
