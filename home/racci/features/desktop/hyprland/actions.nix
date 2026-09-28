{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) escapeShellArg getExe;

  ocrRegion = getExe pkgs.ocr-region;
  screenshot = getExe pkgs.screenshot;
  screenshotCommand = "SCREENSHOT_PICTURES_DIR=${escapeShellArg config.xdg.userDirs.pictures} ${screenshot}";

  colourPicker = getExe pkgs.colour-picker;
in
{
  wayland.windowManager.hyprland = {
    custom-settings.permission.screenCopy = [
      pkgs.grim
      pkgs.hyprpicker
      pkgs.slurp
    ];

    custom-settings.lua = {
      luaModules = [ ./lua/actions.lua ];
      variables = {
        inherit ocrRegion;
        inherit colourPicker;
        screenshotArea = "${screenshotCommand} area";
        screenshotOutput = "${screenshotCommand} output";
        quickAccessCmd = "${pkgs._1password-gui}/bin/1password --quick-access";
        wlogoutCmd = "pkill wlogout || ${pkgs.wlogout}/bin/wlogout -p layer-shell";
      };
      applicationBinds = {
        "SUPER+T" = "${pkgs.alacritty}/bin/alacritty";
        "SUPER+F" = "${pkgs.firefox}/bin/firefox";
        "SUPER+SHIFT+E" = "${pkgs.nautilus}/bin/nautilus --new-window";
      };
    };
  };
}
