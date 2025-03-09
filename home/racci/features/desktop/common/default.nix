{ pkgs, ... }:
{
  imports = [
    ./mobile.nix
    ./nextcloud.nix
    ./office.nix
    ./secrets.nix
    ./zed.nix
  ];

  xdg.mimeApps.enable = true;

  home.packages = with pkgs; [
    health
  ];
}
