{ ... }:
{
  imports = [
    ../../desktop/shared/power.nix
    ../../desktop/shared/appimage.nix
    ../../desktop/shared/xdg.nix
  ];

  core = {
    audio.enable = true;
    bluetooth.enable = true;
  };
}
