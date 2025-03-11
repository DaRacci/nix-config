{ config, lib, ... }:
let
  cfg = config.custom.remote;
in
{
  options.custom.remote = {
    enable = lib.mkEnableOption "Enable remote features";

    remoteDesktop = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable remote desktop";

          startCommand = lib.mkOption {
            type = lib.types.str;
            default = "gnome-session";
            description = "Command to start the remote desktop session.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      xrdp = lib.mkIf cfg.remoteDesktop.enable {
        enable = true;
        defaultWindowManager = cfg.remoteDesktop.startCommand;
        openFirewall = true;
      };

      xserver = lib.mkIf cfg.remoteDesktop.enable {
        enable = true;
        displayManager.gdm = {
          enable = true;
          autoSuspend = false;
        };
        desktopManager.gnome.enable = true;
      };
    };
  };
}
