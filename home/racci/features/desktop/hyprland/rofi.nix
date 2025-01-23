{ config, pkgs, lib, ... }: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    plugins = with pkgs; [
      rofi-vpn
      rofi-top
      rofi-mpd
      rofi-systemd
      rofi-bluetooth
      # rofi-file-browser
    ];

    cycle = true;
    location = "center";
    terminal = lib.getExe config.programs.alacritty.package;
  };
}
