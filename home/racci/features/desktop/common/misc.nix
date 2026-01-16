{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnome-maps
    door-knocker
    bustle
  ];
}
