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

  xdg.configFile.hyprpanel.onChange = lib.mkForce ''
    if [[ $(${pkgs.hyprpanel}/bin/hyprpanel -l) ]]; then
       ${pkgs.hyprpanel}/bin/hyprpanel r
    fi
  '';

  programs.hyprpanel = {
    enable = true;
    theme = "tokyo_night";

    hyprland.enable = true;
    overwrite.enable = true;

    layout = {
      "bar.layouts" = {
        "1" = {
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
        "*" = {
          left = [
            "dashboard"
            "workspaces"
            "windowtitle"
          ];
          middle = [ "media" ];
          right = [
            "volume"
            "clock"
            "notifications"
          ];
        };
      };
    };

    settings = {
      bar = {
        launcher.autoDetectIcon = true;
        media.show_active_only = true;

        notifications = {
          hideCountWhenZero = true;
          show_total = true;
        };

        workspaces = {
          show_numbered = true;
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

      wallpaper.image = "/home/racci/Pictures/Wallpapers.17.jpeg";
    };
  };
}
