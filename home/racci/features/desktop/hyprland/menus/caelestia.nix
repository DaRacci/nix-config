{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (inputs.caelestia-cli.packages.${pkgs.system}) caelestia-cli;
  inherit (inputs.caelestia-shell.packages.${pkgs.system}) caelestia-shell;
in
{
  home.packages = [
    caelestia-cli
    caelestia-shell
  ];
  xdg.configFile = {
    caelestia-cli-config = {
      target = "caelestia/cli.json";
      text = builtins.toJSON {
        theme = {
          enableTerm = false;
          enableHypr = false;
          enableDiscord = false;
          enableFuzzel = false;
          enableBtop = false;
          enableGtk = false;
          enableQt = false;
        };
      };
    };
    caelestia-shell-config = {
      target = "caelestia/shell.json";
      text = builtins.toJSON {
        appearance = {
          anim = {
            durations.scale = 1;
          };

          font = {
            family =
              let
                inherit (config.stylix) fonts;
              in
              {
                material = "Material Symbols Rounded";
                mono = fonts.monospace.name;
                sans = fonts.sansSerif.name;
              };
            size = {
              scale = 1;
            };
          };

          padding.scale = 1;
          rounding.scale = 1;
          spacing.scale = 1;

          transparency = {
            enabled = false;
            base = 1;
            layers = 0.4;
          };
        };

        general = {
          apps = {
            terminal = [ "alacritty" ];
            audio = [ "pavucontrol" ];
          };
        };

        background = {
          enabled = true;
          desktopClock.enabled = false;
        };

        bar = {
          dragThreshold = 20;
          entries = [
            {
              id = "logo";
              enabled = true;
            }
            {
              id = "workspaces";
              enabled = true;
            }
            {
              id = "spacer";
              enabled = true;
            }
            {
              id = "activeWindow";
              enabled = true;
            }
            {
              id = "spacer";
              enabled = true;
            }
            {
              id = "tray";
              enabled = true;
            }
            {
              id = "clock";
              enabled = true;
            }
            {
              id = "statusIcons";
              enabled = true;
            }
            {
              id = "power";
              enabled = true;
            }
          ];
          persistent = true;
          showOnHover = true;
          status = {
            showAudio = false;
            showBattery = true;
            showBluetooth = true;
            showKbLayout = false;
            showNetwork = true;
          };
          workspaces = {
            activeIndicator = true;
            activeLabel = "󰮯 ";
            activeTrail = true;
            label = "  ";
            occupiedBg = false;
            occupiedLabel = "󰮯 ";
            perMonitorWorkspaces = true;
            rounded = true;
            showWindows = false;
            shown = 10;
          };
        };

        border = {
          rounding = 25;
          thickness = 5;
        };

        dashboard = {
          enabled = true;
          dragThreshold = 50;
          mediaUpdateInterval = 500;
          showOnHover = true;
          visualiserBars = 45;
        };

        launcher = {
          actionPrefix = ">";
          dragThreshold = 50;
          vimKeybinds = false;
          enableDangerousActions = true;
          maxShown = 8;
          maxWallpapers = 9;
          useFuzzy = {
            apps = false;
            actions = false;
            schemes = false;
            variants = false;
            wallpapers = false;
          };
        };

        lock = {
          maxNotifs = 5;
        };

        notifs = {
          actionOnClick = true;
          clearThreshold = 0.3;
          defaultExpireTimeout = 5000;
          expandThreshold = 20;
          expire = false;
        };

        osd = {
          hideDelay = 2000;
        };

        paths = {
          mediaGif = "root:/assets/bongocat.gif";
          sessionGif = "root:/assets/kurukuru.gif";
          wallpaperDir = "~/Pictures/Wallpapers";
        };

        services = {
          audioIncrement = 0.1;
          smartScheme = false;
        };

        session = {
          dragThreshold = 30;
          vimKeybinds = false;
          commands = {
            logout = [
              "loginctl"
              "terminate-user"
              ""
            ];
            shutdown = [
              "systemctl"
              "poweroff"
            ];
            hibernate = [
              "systemctl"
              "hibernate"
            ];
            reboot = [
              "systemctl"
              "reboot"
            ];
          };
        };
      };
    };
  };

  systemd.user.services.caelestia-shell = {
    Unit = {
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = config.xdg.configFile.caelestia-shell-config.source;
    };

    Service = {
      ExecStart = lib.getExe caelestia-shell;
      Restart = "on-failure";
    };

    Install = {
      WantedBy = [ config.wayland.systemd.target ];
    };
  };
}
