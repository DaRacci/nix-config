{ config, pkgs, lib, ... }:
let cfg = config.purpose.gaming.simulator; in {
  options.purpose.gaming.simulator = {
    enable = lib.mkEnableOption "Enable simulator support";
    enableRacing = lib.mkEnableOption "Enable Moza Racing";
  };

  config = lib.mkIf (cfg.enable && cfg.racing) {
    home.packages = with pkgs; [
      boxflat
    ];

    xdg.desktopEntries = {
      "boxflat" = {
        name = "Boxflat";
        exec = "${pkgs.boxflat}/bin/boxflat";
        icon = "boxflat";
        categories = [ "Game" ];
      };
    };
  };
}
