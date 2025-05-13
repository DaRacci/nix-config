{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.hyprpanel.homeManagerModules.hyprpanel
  ];

  # TODO - Remove once https://github.com/Jas-SinghFSU/HyprPanel/issues/815 is resolved.
  xdg.configFile.hyprpanel.onChange = lib.mkForce ''
    if [[ $(${pkgs.hyprpanel}/bin/hyprpanel -l) ]]; then
      ${pkgs.hyprpanel}/bin/hyprpanel r
    fi
  '';

  wayland.windowManager.hyprland.settings = {
    exec-once = builtins.map (exec: "${lib.getExe' pkgs.uwsm "uwsm-app"} -s b -- ${exec}") [
      "${lib.getExe' pkgs.blueman "blueman-tray"}"
      "${lib.getExe pkgs.networkmanagerapplet} --indicator"
    ];
  };

  programs.hyprpanel = {
    enable = true;

    hyprland.enable = true;
    overwrite.enable = true;

    settings = {
      layout = {
        "bar.layouts" = {
          "*" = {
            left = [
              "dashboard"
              "workspaces"
              "windowtitle"
            ];
            middle = [ "media" ];
            right = [
              "volume"
              "bluetooth"
              "systray"
              "clock"
              "notifications"
            ];
          };
        };
      };

      bar = {
        autoHide = "fullscreen";
        launcher.autoDetectIcon = true;
        media.show_active_only = true;

        notifications = {
          hideCountWhenZero = true;
          show_total = true;
        };

        # TODO - Specify Icon per Workspace Manually.
        workspaces = {
          monitorSpecific = true;
          showWsIcons = true;
          spacing = 1.0;
        };
      };

      menus.clock = {
        time.military = true;
        weather.location = "Sydney";
        weather.unit = "metric";
      };

      menus.dashboard = {
        directories.enabled = false;
        powermenu.avatar.image = "/home/racci/Pictures/Media/Profile Pictures/James/Main.jpg";
        shortcuts = {
          left = {
            shortcut1 = {
              command = lib.getExe config.programs.firefox.package;
              icon = "󰈹";
            };
            shortcut2 = {
              tooltip = "Spotify";
              command = lib.getExe pkgs.spotify;
            };
          };
        };
        stats = {
          interval = 100;
          enable_gpu = true;
        };
      };

      notifications = {
        position = "top";
      };

      theme = {
        name = "tokyo_night";
        font = {
          name = "Ubuntu Nerd Font";
          size = "1.1rem";
        };

        bar = {
          dropdownGap = "2.35em";
          floating = true;
          layer = "top";
          margin_bottom = "0.5em";
          menus.menu.notifications.height = "25em";
          scaling = 80;
        };

        osd = {
          location = "right";
          muted_zero = true;
          orientation = "vertical";
        };
      };

      wallpaper.image = config.stylix.image;
    };
  };

  custom.uwsm.sliceAllocation.background = [ "hyprpaper" ];
}
