{ ... }:
{
  imports = [
    ./appimage.nix
    ./xdg.nix
  ];

  services.gvfs.enable = true;
}
