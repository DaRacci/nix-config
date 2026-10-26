{ pkgs, ... }:
let
  inherit (pkgs) bustle door-knocker gnome-maps;
in
{
  home.packages = [
    gnome-maps
    door-knocker
    bustle
  ];
}
