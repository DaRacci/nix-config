{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf getExe;
in {
  config = mkIf (config.purpose.gaming.enable && config.wayland.windowManager.hyprland.enable) {
    systemd.user.services.gamemode-watcher = {
      Unit = {
        Description = "Hyprland game mode watcher";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${getExe pkgs.hypr-gamemode}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ config.wayland.systemd.target ];
      };
    };
  };
}
