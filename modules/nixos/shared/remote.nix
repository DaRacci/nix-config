{ config, lib, ... }:
let
  cfg = config.custom.remote;
in
{
  options.custom.remote = {
    enable = lib.mkEnableOption "Enable remote features";

    remoteDesktop = lib.mkOption {
      default = { };
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

    streaming = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable remote streaming";
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

      sunshine = lib.mkIf cfg.streaming.enable {
        enable = true;
        autoStart = true;
        capSysAdmin = true;
        openFirewall = true;
      };
    };

    home-manager.sharedModules = [
      {
        user.persistence.directories = [ ".config/sunshine" ];
      }
    ];

    networking.firewall.allowedTCPPorts = [ 47990 ];
  };
}
