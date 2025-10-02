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
          # settings.port = 47889;
        };

        systemd.user =
          # let
          #   # Loosely based off https://github.com/NixOS/nixpkgs/blob/ad7196ae55c295f53a7d1ec39e4a06d922f3b899/nixos/modules/services/networking/sunshine.nix
          #   basePort = config.services.sunshine.settings.port;
          #   generatePorts = port: offsets: map (offset: port + offset) offsets;
          #   # https://web.archive.org/web/20240303183334/https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
          #   offsets = {
          #     tcp = [
          #       (-5)
          #       0
          #       1
          #       21
          #     ];
          #     udp = [
          #       9
          #       10
          #       11
          #       13
          #     ];
          #   };
          # in
          {
            # sockets.sunshine-proxy = {
            #   wantedBy = [ "sockets.target" ];
            #   socketConfig = {
            #     ListenStream = generatePorts (basePort + 100) offsets.tcp;
            #     ListenDatagram = generatePorts (basePort + 100) offsets.udp;
            #   };
            # };

            # services = {
            # sunshine-proxy = {
            #   bindsTo = [
            #     "sunshine-proxy.socket"
            #     "sunshine.service"
            #   ];
            #   after = [
            #     "sunshine-proxy.socket"
            #     "sunshine.service"
            #   ];
            #   serviceConfig = {
            #     Type = "notify";
            #     RemainAfterExit = "yes";
            #     # https://web.archive.org/web/20240303183334/https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
            #     ExecStart =
            #       (offsets.tcp)
            #       |> generatePorts basePort
            #       |> map (
            #         port:
            #         "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=300s 127.0.0.1:${toString port}"
            #       );
            #     Restart = "no";
            #   };
            # };
            # sunshine = {
            #   serviceConfig = {
            #     Restart = lib.mkForce "no";
            #     ExecStartPost = "${lib.getExe' pkgs.toybox "sleep"} 3"; # Allow sunshine to startup fully
            #   };
            #   unitConfig = {
            #     StopWhenUnneeded = "yes";
            #   };
            # };
            # };
          };

        home-manager.sharedModules = [ { user.persistence.directories = [ ".config/sunshine" ]; } ];
      })

      (lib.mkIf (cfg.streaming.enable && config.programs.hyprland.enable) {
        services.sunshine.applications.apps = [
          {
            name = "Shared Desktop";
            pre-cmd = [
              {
                do = ''sh -c "hyprctl keyword monitor HEADLESS-2,''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS},auto,1"'';
                undo = "hyprctl keyword monitor HEADLESS-2,disable";
              }
            ];
          }
          {
            name = "Exclusive Desktop";
            pre-cmd = [
              {
                do = ''sh -c "hyprctl keyword monitor HEADLESS-2,''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS},auto,1 && hyprctl keyword monitor *-2,disable"'';
                undo = "hyprctl keyword monitor HEADLESS-2,disable";
              }
              (
                let
                  doScript = pkgs.writeShellApplication {
                    name = "hyprland-disable-other-monitors-pre-sunshine";
                    runtimeInputs = [
                      pkgs.hyprland
                      pkgs.jq
                    ];
                    text = ''
                      OUTPUT_FILE="$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json"
                      ENABLED_MONITORS=$(hyprctl -j monitors | jq '. - map(select((.name | contains("headless")) or .disabled == true))')
                      echo $ENABLED_MONITORS > $OUTPUT_FILE

                      for monitor in $(echo $ENABLED_MONITORS | jq -r '.[].name'); do
                        hyprctl keyword monitor "$monitor,disable"
                      done
                    '';
                  };
                  undoScript = pkgs.writeShellApplication {
                    name = "hyprland-restore-disabled-monitors-post-sunshine";
                    runtimeInputs = [
                      pkgs.hyprland
                      pkgs.jq
                    ];
                    text = ''
                      INPUT_FILE="$XDG_STATE_HOME/hyprland-disabled-monitors-pre-sunshine.json"
                      if [ -f "$INPUT_FILE" ]; then
                        for monitor in $(cat $INPUT_FILE | jq -r '.[].name'); do
                          hyprctl keyword monitor "$monitor,enable"
                        done
                        rm $INPUT_FILE
                      fi
                    '';
                  };
                in
                {
                  do = "sh -c '${lib.getExe doScript}'";
                  undo = "sh -c '${lib.getExe undoScript}'";
                }
              )
            ];
          }
        ];

        home-manager.sharedModules = [
          {
            wayland.windowManager.hyprland.settings = {
              exec-once = [ "hyprctl output create headless" ];
              monitor = [ "HEADLESS-2,disable" ];
            };
          }
        ];
      })
    ]
  );
}
