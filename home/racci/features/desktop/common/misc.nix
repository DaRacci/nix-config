{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnome-weather
    gnome-maps
    door-knocker
    bustle
    luminance
  ];

  user.persistence.directories = [ ".local/share/gnome-maps" ];
}
