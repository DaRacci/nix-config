{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    plugins = with pkgs; [
      rofi-games
      rofi-emoji-wayland
      rofi-calc
    ];

    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
        hyprSettings = config.wayland.windowManager.hyprland.settings;

        border-radius = mkLiteral "${toString (hyprSettings.decoration.rounding * 1.5)}px";
      in
      {
        window = {
          width = mkLiteral "50em";
          height = mkLiteral "34em";

          transparency = "real";
          spacing = mkLiteral "0em";
          padding = mkLiteral "0em";

          border-color = mkLiteral "@blue";
          border = mkLiteral "${toString hyprSettings.general.border_size}px";
          inherit border-radius;
        };

        element = {
          inherit border-radius;
        };

        wallbox = {
          inherit border-radius;
        };
      };

    extraConfig = {
      run-command = "${lib.getExe' pkgs.uwsm "uwsm-app"} -s a -- {cmd}";

      kb-accept-alt = "Control+space";
      kb-row-select = "";
    };

    cycle = true;
    location = "top";
    terminal = lib.getExe config.programs.alacritty.package;
  };
}
