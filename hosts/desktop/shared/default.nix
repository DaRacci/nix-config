{ inputs, ... }: {
  imports = [
    inputs.stylix.nixosModules.stylix

    ./appimage.nix
    ./xdg.nix
  ];

  custom.core = {
    audio.enable = true;
    bluetooth.enable = true;
  };

  services.gvfs.enable = true;
}
