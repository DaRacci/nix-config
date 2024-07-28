{ flake, ... }: {
  imports = [
    "${flake}/hosts/shared/optional/stylix.nix"

    ./appimage.nix
    ./xdg.nix
  ];

  custom.core = {
    audio.enable = true;
    bluetooth.enable = true;
  };

  services.gvfs.enable = true;
}
