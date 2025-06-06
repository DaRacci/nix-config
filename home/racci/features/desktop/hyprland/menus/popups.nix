{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
in
{
  wayland.windowManager.hyprland.custom-settings.slideIn = [
    {
      bind = "SUPER+b";
      exec = getExe pkgs.bitwarden;
      class = "Bitwarden";
      side = "top";
    }
    {
      bind = "SUPER+c";
      exec = getExe pkgs.gnome-calculator;
      class = "org.gnome.Calculator";
      side = "top";
      rule = {
        size = {
          width = "19%";
          height = "33%";
        };
        move.x = "40%";
      };
    }
    {
      bind = "SUPER+d";
      class = "me.iepure.devtoolbox";
      exec = getExe pkgs.devtoolbox;
      side = "top";
    }
    {
      bind = "SUPER+e";
      exec = getExe pkgs.nautilus;
      class = "org.gnome.Nautilus";
      side = "right";
      rule = {
        size = {
          width = "33%";
          height = "33%";
        };
        move.x = "33%";
        move.y = "67%";
      };
    }
  ];
}
