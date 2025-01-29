{ flake, ... }:
{
  imports = [
    "${flake}/hosts/shared/optional/stylix.nix"

    ./power.nix
    ../../desktop/shared/appimage.nix
    ../../desktop/shared/xdg.nix
  ];

  custom.core = {
    audio.enable = true;
    bluetooth.enable = true;
  };
}
