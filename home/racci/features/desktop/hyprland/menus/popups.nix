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
      exec = getExe pkgs.bitwarden-desktop;
      class = "Bitwarden";
      position = "top";
      extProp = {
        unfocus = "hide";
      };
    }
    {
      bind = "SUPER+c";
      exec = getExe pkgs.gnome-calculator;
      class = "org.gnome.Calculator";
      position = "top";
      size = {
        width = "19%";
        height = "33%";
      };
    }
    {
      bind = "SUPER+e";
      exec = getExe pkgs.nautilus;
      class = "org.gnome.Nautilus";
      position = "right";
      size.width = "18%";
      extProp.unfocus = "hide";
    }
  ];
}
