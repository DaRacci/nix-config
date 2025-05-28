{ ... }:
{
  imports = [
    ./appimage.nix
    ./power.nix
  ];

  services.gvfs.enable = true;
}
