{
  config,
  pkgs,
  lib,
  ...
}:
let
  monitors = {
    left = "DP-1";
    center = "DP-6";
    right = "HDMI-A-1";
  };
in
{
  wayland.windowManager.hyprland.custom-settings.workspaces = {
    enable = true;
    definitions = {
      "1" = {
        name = "Terminal";
        monitor = monitors.center;
        startup = [ (lib.getExe pkgs.alacritty) ];
      };
      "2" = {
        name = "Browser";
        monitor = monitors.left;
        startup = [ (lib.getExe config.programs.firefox.package) ];
      };
      "3" = {
        name = "Files & Knowledge";
        monitor = monitors.left;
        startup = [ (lib.getExe pkgs.obsidian) ];
      };
      "4" = {
        name = "Social";
        monitor = monitors.right;
        startup = [ (lib.getExe pkgs.discord) ];
      };
      "5" = {
        name = null;
        monitor = monitors.right;
      };
      "6" = {
        name = "Media";
        monitor = monitors.center;
      };
      "7" = {
        name = "Development";
        monitor = monitors.center;
        startup = [ (lib.getExe config.programs.zed-editor.package) ];
      };
      "8" = {
        name = "Gaming";
        monitor = monitors.center;
      };
      "9" = {
        name = "Miscellaneous";
        monitor = monitors.left;
        startup = [ (lib.getExe pkgs.feishin) ];
      };
      "10" = {
        name = "Miscellaneous";
        monitor = monitors.left;
      };
    };
  };
}
