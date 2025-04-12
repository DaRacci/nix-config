{ pkgs, ... }:
{
  imports = [
    ./keyboard.nix
    ./kvm.nix
    ./misc.nix
    ./mobile.nix
    ./office.nix
    ./secrets.nix
    ./sync.nix
    ./zed.nix
  ];

  xdg.mimeApps.enable = true;

  home.packages = with pkgs; [
    health
    fragments
    transmission_4-gtk
    kooha
  ];
}
