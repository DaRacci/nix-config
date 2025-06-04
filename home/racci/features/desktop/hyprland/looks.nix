{ config, ... }:
{
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 4;
      gaps_out = 5;
      gaps_workspaces = 50;
      border_size = 2;
    };

    animations = {
      enabled = true;

      bezier = [
        "fluentDecel, 0, 0.2, 0.4, 1"
        "easeOutCirc, 0, 0.55, 0.45, 1"
        "easeOutCubic, 0.33, 1, 0.68, 1"
        "easeInOutSine, 0.37, 0, 0.63, 1"
      ];

      # https://wiki.hyprland.org/Configuring/Animations/#animation-tree
      animation = [
        "windowsIn, 1, 3, easeOutCubic, popin 30"
        "windowsOut, 1, 3, fluentDecel, popin 70"
        "windowsMove, 1, 2, easeInOutSine, slide"

        "fadeIn, 1, 3, easeOutCubic"
        "fadeOut, 1, 2, easeOutCubic"
        "fadeSwitch, 0, 1, easeOutCirc"
        "fadeShadow, 1, 10, easeOutCirc"
        "fadeDim, 1, 4, fluentDecel"
        "border, 1, 2.7, easeOutCirc"
        "borderangle, 1, 30, fluentDecel, once"
        "workspaces, 1, 4, easeOutCubic, fade"

        "layers, 1, 6, easeOutCubic, slide top"
      ];
    };

    decoration = {
      active_opacity = 1;
      inactive_opacity = 1;
      fullscreen_opacity = 1;

      rounding = 20;

      blur = {
        enabled = true;
        xray = true;
        special = true;
        new_optimizations = true;
        size = 14;
        passes = 4;
        brightness = 1;
        noise = 0.01;
        contrast = 1;
        popups = false;
      };

      shadow = {
        enabled = true;
        range = 20;
        render_power = 4;
        ignore_window = true;
        offset = "0 2";
      };

      dim_inactive = false;
      dim_strength = 0.1;
      dim_special = 0;
    };

    workspace = [
      # region Smart Gaps & Transparency
      "w[tv1], gapsout:0, gapsin:0"
      "f[1], gapsout:0, gapsin:0"
    ];

    windowrulev2 = [
      "bordersize 0, floating:0, onworkspace:w[tv1]"
      "rounding 0, floating:0, onworkspace:w[tv1]"
      "bordersize 0, floating:0, onworkspace:f[1]"
      "rounding 0, floating:0, onworkspace:f[1]"
      #endregion
      "bordercolor rgba(ffabf1AA) rgba(ffabf177),pinned:1"
    ];

    plugins = {
      hyprbars = {
        bar_color = "rgb(2a2a2a)";
        bar_height = 28;
        col_text = "rgba(ffffffdd)";
        bar_text_size = 12;
        bar_text_font = "JetBrainsMono Nerd Font";

        buttons = {
          button_size = 0;
          "col.maximize" = "rgba(ffffff11)";
          "col.close" = "rgba(ff111133)";
        };
      };

      hyprfocus = {
        enabled = true;
        animate_floating = true;
        animate_workspacechange = true;
        focus_animation = "shrink";
        shrink = {
          shrink_percentage = 0.9;
          in_bezier = "realsmooth";
          in_speed = 1;
          out_bezier = "realsmooth";
          out_speed = 2;
        };
      };

      dynamic-cursors = {
        enabled = true;
        mode = "tilt";
        threshold = 2;

        rotate = {
          length = config.stylix.cursor.size;
          offset = 0.0;
        };

        shake = {
          enabled = true;
          nearest = true;
          threshold = 6.0;
          base = 4.0;
          speed = 4.0;
          influence = 0.0;
          limit = 0.0;
          timeout = 2000;
          effects = true;
          ipc = false;
        };

        hyprcursor = {
          enabled = true;
          nearest = true;

          resolution = -1;
          fallback = "clientside";
        };
      };
    };
  };
}
