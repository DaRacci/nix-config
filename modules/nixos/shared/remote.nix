{
  config,
  pkgs,
  lib,
  ...
}:
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.remoteDesktop.enable {
        services.xrdp = lib.mkIf cfg.remoteDesktop.enable {
          enable = true;
          defaultWindowManager = cfg.remoteDesktop.startCommand;
          openFirewall = true;
        };
      })

      (lib.mkIf cfg.streaming.enable {
        services.sunshine = lib.mkIf cfg.streaming.enable {
          enable = true;
          autoStart = false;
          openFirewall = true;
          capSysAdmin = true;
          settings.port = 47889;
        };

        systemd.user = {
          sockets.sunshine-proxy = {
            wantedBy = [ "sockets.target" ];
            socketConfig.ListenStream = "47990";
          };

          services = {
            sunshine-proxy = {
              bindsTo = [
                "sunshine-proxy.socket"
                "sunshine.service"
              ];
              after = [
                "sunshine-proxy.socket"
                "sunshine.service"
              ];
              serviceConfig = {
                Type = "notify";
                ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=500s 127.0.0.1:47890";
                Restart = "no";
              };

            };
            sunshine = {
              serviceConfig = {
                Restart = lib.mkForce "no";
                ExecStartPost = "${lib.getExe' pkgs.toybox "sleep"} 3"; # Allow sunshine to startup
              };
              unitConfig = {
                StopWhenUnneeded = "yes";
              };
            };
          };
        };

        home-manager.sharedModules = [ { user.persistence.directories = [ ".config/sunshine" ]; } ];
      })
    ]
  );
}
