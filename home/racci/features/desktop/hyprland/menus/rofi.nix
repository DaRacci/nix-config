{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    plugins = with pkgs; [
      rofi-games
      rofi-emoji-wayland
      rofi-calc
    ];

    cycle = true;
    location = "center";
    terminal = lib.getExe config.programs.alacritty.package;
  };
}
