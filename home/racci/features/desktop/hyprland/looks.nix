{
  config,
  lib,
  ...
}:
with lib;
{
  # Smart-gaps: tiled windows on special workspaces get border 0 / rounding 0
  # via custom-settings.windowrule (camelCase Nix API, Lua output handled by module)
  wayland.windowManager.hyprland.custom-settings.windowrule = {
    "smart-gaps-tiled-float-tv1" = {
      matcher = [
        {
          float = false;
          workspace = {
            name = "w[tv1]";
          };
        }
      ];
      rule = {
        borderSize = 0;
        rounding = 0;
      };
    };
    "smart-gaps-tiled-float-f1" = {
      matcher = [
        {
          float = false;
          workspace = {
            name = "f[1]";
          };
        }
      ];
      rule = {
        borderSize = 0;
        rounding = 0;
      };
    };
  };

  # Pin-border windowrule — direct Lua entry (bordercolor not supported in custom module)
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match = {
        pin = true;
      };
      border_color = {
        colors = [
          "rgba(ffabf1AA)"
          "rgba(ffabf177)"
        ];
      };
    }
  ];

  wayland.windowManager.hyprland.settings = {
    config = {
      general = {
        gaps_in = 4;
        gaps_out = 5;
        gaps_workspaces = 50;
        border_size = 2;
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
          offset = "0 2";
        };

        dim_inactive = false;
        dim_strength = 0.1;
        dim_special = 0;
      };

      plugin = {
        dynamic_cursors = {
          enabled = true;
          mode = "tilt";
          threshold = 2;

          rotate = {
            length = config.stylix.cursor.size;
            offset = 0.0;
          };

          shake = {
            enabled = true;
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

    # curve renders via _args: hl.curve(name, { type = "bezier", points = { ... } })
    curve = [
      {
        _args = [
          "fluentDecel"
          (generators.mkLuaInline ''{ type = "bezier", points = { { 0, 0.2 }, { 0.4, 1 } } }'')
        ];
      }
      {
        _args = [
          "easeOutCirc"
          (generators.mkLuaInline ''{ type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } }'')
        ];
      }
      {
        _args = [
          "easeOutCubic"
          (generators.mkLuaInline ''{ type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } }'')
        ];
      }
      {
        _args = [
          "easeInOutSine"
          (generators.mkLuaInline ''{ type = "bezier", points = { { 0.37, 0 }, { 0.63, 1 } } }'')
        ];
      }
    ];

    # animation entries with Lua field names: leaf, enabled, speed, bezier, style
    animation = [
      {
        leaf = "windowsIn";
        enabled = true;
        speed = 3;
        bezier = "easeOutCubic";
        style = "popin 30";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 3;
        bezier = "fluentDecel";
        style = "popin 70";
      }
      {
        leaf = "windowsMove";
        enabled = true;
        speed = 2;
        bezier = "easeInOutSine";
        style = "slide";
      }
      {
        leaf = "fadeIn";
        enabled = true;
        speed = 3;
        bezier = "easeOutCubic";
      }
      {
        leaf = "fadeOut";
        enabled = true;
        speed = 2;
        bezier = "easeOutCubic";
      }
      {
        leaf = "fadeSwitch";
        enabled = false;
        speed = 1;
        bezier = "easeOutCirc";
      }
      {
        leaf = "fadeShadow";
        enabled = true;
        speed = 10;
        bezier = "easeOutCirc";
      }
      {
        leaf = "fadeDim";
        enabled = true;
        speed = 4;
        bezier = "fluentDecel";
      }
      {
        leaf = "border";
        enabled = true;
        speed = 2.7;
        bezier = "easeOutCirc";
      }
      {
        leaf = "borderangle";
        enabled = true;
        speed = 30;
        bezier = "fluentDecel";
        style = "once";
      }
      {
        leaf = "workspaces";
        enabled = true;
        speed = 4;
        bezier = "easeOutCubic";
        style = "fade";
      }
      {
        leaf = "layers";
        enabled = true;
        speed = 6;
        bezier = "easeOutCubic";
        style = "slide top";
      }
    ];

    # workspace_rule for smart-gaps (separate from custom-settings windowrule)
    workspace_rule = [
      {
        workspace = "w[tv1]";
        gaps_out = 0;
        gaps_in = 0;
      }
      {
        workspace = "f[1]";
        gaps_out = 0;
        gaps_in = 0;
      }
    ];
  };
}
