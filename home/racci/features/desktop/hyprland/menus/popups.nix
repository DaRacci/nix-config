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
      position = "edge";
    }
    {
      bind = "SUPER+c";
      exec = getExe pkgs.gnome-calculator;
      class = "org.gnome.Calculator";
      position = "edge";
      rule = {
        size = {
          width = "19%";
          height = "33%";
        };
        # move.x = "40%";
      };
    }
    {
      bind = "SUPER+d";
      class = "me.iepure.devtoolbox";
      exec = getExe pkgs.devtoolbox;
      side = "edge";
    }
    {
      bind = "SUPER+e";
      exec = getExe pkgs.nautilus;
      class = "org.gnome.Nautilus";
      position = "side";
      rule = {
        size.width = "18%";
        # move.x = "81%";
      };
    }
  ];
}
