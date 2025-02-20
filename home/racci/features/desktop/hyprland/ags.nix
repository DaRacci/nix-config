{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # inputs.ags.homeManagerModules.default
    inputs.hyprpanel.homeManagerModules.hyprpanel
  ];

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
      bar.launcher.autoDetectIcon = true;
      bar.media.show_active_only = true;

      bar.notifications.hideCountWhenZero = true;
      bar.notifications.show_total = true;

      bar.workspaces.show_numbered = true;
      bar.workspaces.spacing = 1.0;

      menus.clock = {
        time.military = true;
        weather.location = "Sydney";
        weather.unit = "metric";
      };

      menus.dashboard = {
        directories.enabled = false;
        powermenu.avatar.image = "/home/racci/Pictures/Media/Profile Pictures/James/Main.jpg";
        shortcuts = {
          left.shortcut1.command = lib.getExe config.programs.firefox.package;
          left.shortcut1.icon = "󰈹";
          left.shortcut1.tooltip = "Firefox";
          left.shortcut2.command = lib.getExe pkgs.spotify;
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

  # home.packages = with inputs.astal.packages.${pkgs.system}; [
  #   default
  #   io
  # ];

  # programs.ags = {
  #   enable = true;
  #   # configDir = "${inputs.asztal}/ags";

  #   extraPackages =
  #     with pkgs;
  #     [
  #       fzf
  #       bun
  #       gtksourceview
  #       # webkitgtk
  #       accountsservice
  #       dart-sass
  #       gtk3
  #       gtk4
  #     ]
  #     ++ (with inputs.ags.packages.${pkgs.system}; [
  #       apps
  #       auth
  #       battery
  #       bluetooth
  #       hyprland
  #       mpris
  #       network
  #       notifd
  #       powerprofiles
  #       tray
  #       wireplumber
  #       inputs.astal.packages.${pkgs.system}.default
  #     ]);
  # };
}
