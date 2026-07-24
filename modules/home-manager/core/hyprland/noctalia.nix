{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf mkMerge getExe;

  cfg = config.core.profile;

  noctaliaSettings = {
    bar = {
      order = [
        "default"
        "side_bar"
      ];

      default = {
        background_opacity = 0.9;
        capsule_border = "primary";
        center = [
          "media"
          "spacer_bar"
          "workspaces"
          "spacer_bar"
          "active_window"
        ];
        contact_shadow = true;
        end = [
          "tray"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "session"
        ];
        margin_edge = 4;
        padding = 32;
        start = [
          "launcher"
          "spacer_bar"
          "clock"
          "spacer_bar"
          "privacy"
          "recorder"
          "screenshot"
        ];
      };

      side_bar = {
        enable = false; # Disable by default - Add monitor overrides to enable.
        background_opacity = 0.9;
        center = [ "workspaces" ];
        end = [
          "tray"
          "notifications"
          "volume"
          "brightness"
        ];
        margin_edge = 0;
        margin_ends = 0;
        padding = 32;
        start = [ "clock" ];
      };
    };

    brightness.enable_ddcutil = true;
    calendar.enabled = true;

    control_center.shortcuts = [
      { type = "caffeine"; }
      { type = "nightlight"; }
      { type = "notification"; }
      { type = "power_profile"; }
      { type = "noctalia/screen_recorder:toggle"; }
    ];

    desktop_widgets.enabled = false;
    lockscreen.enabled = false;
    lockscreen_widgets.enabled = false;

    notification.layer = "overlay";
    osd.kinds.media = false;

    plugin_settings."noctalia/screen_recorder" = {
      color_range = "full";
      directory = config.xdg.userDirs.videos;
      replay_duration = 60;
      replay_enabled = true;
    };

    plugins.enabled = [
      "noctalia/screen_recorder"
      "noctalia/translator"
      "noctalia/timer"
    ];

    shell = {
      font_family = config.stylix.fonts.sansSerif.name;
      avatar_path = cfg.avatar.path;
      launch_apps_as_systemd_services = true;
      screen_time_enabled = true;
      settings_show_advanced = true;
      telemetry_enabled = false;

      panel = {
        launcher_placement = "attached";
        clipboard_placement = "attached";
        open_near_click_control_center = true;
        open_near_click_session = true;
        open_near_click_wallpaper = true;
        transparency_mode = "soft";
      };

      screen_corners.enabled = true;

      screenshot = {
        directory = "${config.xdg.userDirs.pictures}/Screenshots";
        filename_pattern = "%Y/%m/Screenshot_%Y%m%d_%H%M%S";
        pipe_command = ''${getExe pkgs.satty} -f - --output-filename "${config.xdg.userDirs.pictures}/Screenshots/%Y/%m/Screenshot_$(date '+%Y%m%d_%H%M%S')"'';
        pipe_to_command = true;
      };

      session.actions = [
        {
          action = "lock";
          enabled = true;
          shortcut = "1";
          variant = "default";
        }
        {
          action = "logout";
          enabled = true;
          shortcut = "2";
          variant = "default";
        }
        {
          action = "reboot";
          enabled = true;
          shortcut = "3";
          variant = "default";
        }
        {
          action = "shutdown";
          enabled = true;
          shortcut = "4";
          variant = "destructive";
        }
      ];
    };

    theme = {
      builtin = "Noctalia";
      mode = "dark";
      # source = "builtin";
      templates = {
        enable_builtin_templates = false;
        enable_community_templates = false;
      };
    };

    wallpaper = {
      directory = cfg.wallpaper.directory;
      automation.enabled = true;
    };

    widget = {
      audio_visualizer.anchor = true;
      brightness.show_label = false;
      tray.drawer = true;
      volume.show_label = false;
      recorder.type = "noctalia/screen_recorder:recorder";

      clock = {
        font_family = config.stylix.fonts.monospace.name;
        vertical_format = "{:%H\\n%M}";
      };

      privacy = {
        cam_filter_regex = ".Discord-wrapped";
        hide_inactive = true;
      };

      spacer_bar = {
        length = 32;
        type = "spacer";
      };

      workspaces = {
        anchor = true;
        labels_only_when_occupied = true;
        max_label_chars = 2;
      };
    };
  };
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  config = mkMerge [
    {
      home.packages = [
        pkgs.gpu-screen-recorder # Required for the screen recording plugin.
      ];

      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        validateConfig = true;
        settings = noctaliaSettings;
        package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      wayland.windowManager.hyprland = {
        custom-settings.permission.screenCopy = [
          (getExe config.programs.noctalia.package)
        ];

        settings = {
          layer_rule = [
            {
              match = {
                namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd)$";
              };
              blur = true;
              ignore_alpha = 0.5;
              blur_popups = true;
            }
          ];
        };
      };

      user.persistence.directories = [
        ".local/share/noctalia"
      ];
    }

    (mkIf (cfg.location.secret != null) {
      sops = {
        secrets.${cfg.location.secret} = { };
        templates."NOCTALIA_${cfg.location.secret}" = {
          path = "${config.xdg.configHome}/noctalia/location.toml";
          content = ''
            [location]
            address = "${config.sops.placeholder.${cfg.location.secret}}"
          '';
        };
      };
    })
  ];
}
