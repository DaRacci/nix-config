{ config, pkgs, lib, ... }: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    plugins = with pkgs; [
      rofi-calc
      rofimoji
      rofi-vpn
      rofi-top
      rofi-mpd
      rofi-systemd
      rofi-bluetooth
      rofi-screenshot
      rofi-power-menu
      rofi-file-browser
      todofi-sh
    ];

    cycle = true;
    location = "center";
    terminal = lib.getExe config.programs.alacritty.package;
  };
}
