{ ... }:
{
  imports = [
    ./appimage.nix
    ./xdg.nix
    ./power.nix
  ];

  services.gvfs.enable = true;
  networking.interfaces.eth0.wakeOnLan.enable = true;
}
