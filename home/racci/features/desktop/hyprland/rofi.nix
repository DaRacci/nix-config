{ config, pkgs, lib, ... }: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;

    location = "center";
    terminal = lib.getExe config.programs.alacritty.package;

    theme = {
      "*" = {
        main-bg = "#24283be6";
        main-fg = "#c0caf5ff";
        main-br = "#bb9af7ff";
        main-ex = "#7dcfffcc";
        select-bg = "#7aa2f7ff";
        select-fg = "#24283bff";
        separatorcolor = "transparent";
        border-color = "transparent";
      };
    };
  };
}
