{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    optionalAttrs
    optionals
    ;
  cfg = config.core.gaming;
  hasHomeManager = config ? home-manager;
in
{
  options.core.gaming = {
    enable = mkEnableOption "Enable gaming features";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      custom.defaultGroups = [
        "adbusers" # For Oculus Quest ADB access
      ];

      hardware = {
        steam-hardware.enable = true;
        graphics = {
          enable = true;
          enable32Bit = true;
        };
      };

      nixpkgs.overlays = [
        (_: prev: {
          gamescope-session = prev.gamescope-session.overrideAttrs (_: {
            prePatch = ''
              substituteInPlace gamescope-session \
                --replace-fail "-w 1280 -h 800" "-w 3840 -h 2160" \
                --replace-fail "exec gamescope \\" "
                export STEAM_DISPLAY_REFRESH_LIMITS=48,240
                export STEAM_GAMESCOPE_FORCE_HDR_DEFAULT=1
                export STEAM_GAMESCOPE_FORCE_OUTPUT_TO_HDR10PQ_DEFAULT=1
                exec gamescope \\"
            '';
          });
        })
      ];

      environment.systemPackages = with pkgs; [
        android-tools
      ];

      programs = {
        steam = {
          enable = true;
          package = pkgs.steam.override {
            extraArgs = "-steamos3 -steamdeck -steampal -gamepadui";
            extraEnv = {
              PRESSURE_VESSEL_SYSTEMD_SCOPE = 1;
              PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES = 1;
              PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
            };
          };
          extest.enable = true;
          extraPackages = with pkgs; [
            xwayland-run

            # Steam logs errors about missing these, not sure for what though.
            xwininfo
          ];
          extraCompatPackages = [ pkgs.proton-ge-bin ];

          remotePlay.openFirewall = true;
          localNetworkGameTransfers.openFirewall = true;
        };
      };

      services = {
        wivrn = {
          enable = true;
          package = pkgs.wivrn;
          openFirewall = true;
          autoStart = true;
          steam.importOXRRuntimes = true;
          highPriority = true;
          monadoEnvironment = {

          };
          config = {
            enable = true;
            json = {
              scale = [
                0.75
                0.5
              ];
              bitrate = 100000000;
              encoders = [
                {
                  encoder = "nvenc";
                  codec = "h265";
                  width = 0.5;
                  height = 1;
                  offset_x = 0;
                  offset_y = 0;
                  group = 0;
                }
                {
                  encoder = "nvenc";
                  codec = "h265";
                  width = 0.5;
                  height = 1;
                  offset_x = 0.5;
                  offset_y = 0;
                  group = 0;
                }
              ];
              application = [ pkgs.wayvr ];
            };
          };
        };

        udev = {
          extraRules = ''
            SUBSYSTEM=="sound", ACTION=="change", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", ENV{SOUND_DESCRIPTION}="Wireless Controller"
            SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0186", MODE="0660", TAG+="uaccess", SYMLINK+="ocuquest%n"
            SUBSYSTEM=="tty", KERNEL=="ttyACM*", ATTRS{idVendor}=="346e", ACTION=="add", MODE="0666", TAG+="uaccess"
          '';
        };
      };

      networking.firewall =
        let
          alvrPorts = optionals config.programs.alvr.enable [
            9942 # OSC
            8082 # Web
          ];
        in
        {
          allowedUDPPorts = alvrPorts;
          allowedTCPPorts = [ 24070 ] ++ alvrPorts;
        };
    }

    (mkIf (config.jovian.decky-loader.enable or false) {
      # Do not auto-start decky-loader at boot, the decky-loader-steam-watch
      # user service manages its lifecycle alongside the Steam process.
      systemd.services.decky-loader = {
        wantedBy = mkForce [ ];
        serviceConfig = {
          # Suppress the CSS_Loader health-check spam that fires every few seconds
          # whenever Steam's internal web interface (port 8080) is not running.
          LogFilterPatterns = "~\\[CSS_Loader\\].*\\[Health Check\\].*Cannot connect";
        };
      };

      # Allow any active local user session to start/stop decky-loader without a password prompt
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "decky-loader.service" &&
              (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
              subject.local && subject.active) {
            return polkit.Result.YES;
          }
        });
      '';

      home-manager = optionalAttrs hasHomeManager {
        sharedModules = [
          (
            {
              pkgs,
              lib,
              osConfig ? null,
              ...
            }:
            let
              deckyLoaderSteamWatch = pkgs.writeShellScript "decky-loader-steam-watch" ''
                STEAM_PID_FILE="$HOME/.steam/steam.pid"

                while true; do
                  while true; do
                    if [ -f "$STEAM_PID_FILE" ]; then
                      STEAM_PID=$(cat "$STEAM_PID_FILE" 2>/dev/null || true)
                      if [ -n "$STEAM_PID" ] && kill -0 "$STEAM_PID" 2>/dev/null; then
                        break
                      fi
                    fi
                    sleep 3
                  done

                  systemctl start decky-loader.service || true

                  # tail --pid blocks until the given PID exits, then returns immediately.
                  tail --pid="$STEAM_PID" -f /dev/null 2>/dev/null || true
                  systemctl stop decky-loader.service || true

                  sleep 2
                done
              '';
            in
            {
              config = lib.mkIf (osConfig != null && (osConfig.jovian.decky-loader.enable or false)) {
                systemd.user.services.decky-loader-steam-watch = {
                  Unit = {
                    Description = "Manage decky-loader lifecycle with Steam";
                    After = [ "graphical-session-pre.target" ];
                    PartOf = [ "graphical-session.target" ];
                  };
                  Service = {
                    Type = "simple";
                    ExecStart = "${deckyLoaderSteamWatch}";
                    Restart = "always";
                    RestartSec = "5s";
                  };
                  Install = {
                    WantedBy = [ "graphical-session.target" ];
                  };
                };
              };
            }
          )
        ];
      };
    })
  ]);
}
