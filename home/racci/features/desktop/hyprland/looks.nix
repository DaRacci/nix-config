{ config, ... }:
{
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 4;
      gaps_out = 5;
      gaps_workspaces = 50;
      border_size = 4;
    };

    animations = {
      enabled = true;

      bezier = [
        "fluent_decel, 0, 0.2, 0.4, 1"
        "easeOutCirc, 0, 0.55, 0.45, 1"
        "easeOutCubic, 0.33, 1, 0.68, 1"
        "easeinoutsine, 0.37, 0, 0.63, 1"
      ];

      animation = [
        "windowsIn, 1, 3, easeOutCubic, popin 30" # window open
        "windowsOut, 1, 3, fluent_decel, popin 70" # window close.
        "windowsMove, 1, 2, easeinoutsine, slide" # everything in between, moving, dragging, resizing.

        # Fade
        "fadeIn, 1, 3, easeOutCubic" # fade in (open) -> layers and windows
        "fadeOut, 1, 2, easeOutCubic" # fade out (close) -> layers and windows
        "fadeSwitch, 0, 1, easeOutCirc" # fade on changing activewindow and its opacity
        "fadeShadow, 1, 10, easeOutCirc" # fade on changing activewindow for shadows
        "fadeDim, 1, 4, fluent_decel" # the easing of the dimming of inactive windows
        "border, 1, 2.7, easeOutCirc" # for animating the border's color switch speed
        "borderangle, 1, 30, fluent_decel, once" # for animating the border's gradient angle - styles: once (default), loop
        "workspaces, 1, 4, easeOutCubic, fade" # styles: slide, slidevert, fade, slidefade, slidefadevert
      ];
    };

    decoration = {
      active_opacity = 1;
      inactive_opacity = 0.90;
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
        popups = true;
        popups_ignorealpha = 0.6;
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
