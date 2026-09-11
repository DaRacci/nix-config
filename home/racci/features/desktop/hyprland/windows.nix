{
  pkgs,
  lib,
  ...
}:
{
  wayland.windowManager.hyprland.custom-settings.lua = {
    luaModules = [
      ./lua/windows.lua
      ./lua/tags.lua
    ];
    variables.takeControlConnectingTitleRegex = lib.strings.escapeRegex " - Connecting [v. ${pkgs.take-control-viewer.version}] [0:00:00]";
  };
}
