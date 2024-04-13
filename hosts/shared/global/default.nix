_: {
  imports = [
    ./appimage.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./passwords.nix
    ./sops.nix
    ./security.nix
    ./zram.nix
  ];

  environment = {
    enableAllTerminfo = true;
    sessionVariables.NIXOS_OZONE_WL = "1";
  };

  hardware.enableRedistributableFirmware = true;

  programs.nix-ld.enable = true;
}
