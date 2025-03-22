{ ... }:
{
  imports = [
    ./power.nix
    ../../desktop/shared/appimage.nix
    ../../desktop/shared/xdg.nix
  ];

  custom.core = {
    audio.enable = true;
    bluetooth.enable = true;
  };
}
