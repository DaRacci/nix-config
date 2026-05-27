{
  self,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
{
  imports = [
    "${self}/home/racci/features/desktop/common"
    "${self}/home/shared/desktop/hyprland"

    ./actions.nix
    ./display.nix
    ./input.nix
    ./lock-suspend.nix
    ./looks.nix
    ./menus
    ./windows.nix
    ./workspaces.nix
  ];

  home.file.".local/bin/wlprop" = {
    executable = true;
    source = "${
      pkgs.writeShellApplication {
        name = "wlprop";
        runtimeInputs = with pkgs; [
          hyprland
          jq
          slurp
        ];
        text = ''
          TREE=$(hyprctl clients -j | jq -r '.[] | select(.hidden==false and .mapped==true)')
          SELECTION=$(echo "''${TREE}" | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp)

          X=$(echo "''${SELECTION}" | awk -F'[, x]' '{print $1}')
          Y=$(echo "''${SELECTION}" | awk -F'[, x]' '{print $2}')
          W=$(echo "''${SELECTION}" | awk -F'[, x]' '{print $3}')
          H=$(echo "''${SELECTION}" | awk -F'[, x]' '{print $4}')

          # shellcheck disable=SC2016
          echo "''${TREE}" | jq -r --argjson x "''${X}" --argjson y "''${Y}" --argjson w "''${W}" --argjson h "''${H}" '. | select(.at[0]==$x and .at[1]==$y and .size[0]==$w and.size[1]==$h)'
        '';
      }
    }/bin/wlprop";
  };

  services.hyprpolkitagent.enable = true;

  xdg.configFile."uwsm/env".text = config.lib.shell.exportAll {
    #region Toolkit Backends
    GTK_BACKEND = "wayland,x11";
    QT_QPA_PLATFORM = "wayland;xcb";
    # "SDL_VIDEODRIVER,wayland" # Breaks osu! hardware acceleration
    CLUTTER_BACKEND = "wayland";
    NIXOS_OZONE_WL = "1";
    #endregion
  };

  wayland.windowManager.hyprland = {
    systemd.enable = false;
    configType = "lua";

    plugins = with pkgs.hyprlandPlugins; [
      hy3
      hypr-dynamic-cursors
    ];

    custom-settings.permission.plugin =
      with pkgs.hyprlandPlugins;
      [
        hy3
        hypr-dynamic-cursors
      ]
      |> map (plugin: "${plugin}/lib/lib${plugin.pname}.so");

    custom-settings.bind = {
      # Media transport: no modifiers
      XF86AudioPause = {
        action = [
          "exec"
          "${getExe config.services.playerctld.package} play-pause"
        ];
      };
      XF86AudioPlay = {
        action = [
          "exec"
          "${getExe config.services.playerctld.package} play-pause"
        ];
      };
      XF86AudioNext = {
        action = [
          "exec"
          "${getExe config.services.playerctld.package} next"
        ];
      };
      XF86AudioPrev = {
        action = [
          "exec"
          "${getExe config.services.playerctld.package} previous"
        ];
      };

      # Window management via custom-settings.bind
      "SUPER+Q" = {
        action = [ "killactive" ];
      };
      "SUPER+SPACE" = {
        action = [ "fullscreen" ];
      };
      "SUPER+SHIFT+SPACE" = {
        action = [ "togglefloating" ];
      };
    };

    settings = {
      config = {
        debug.disable_logs = true;

        ecosystem = {
          no_update_news = true;
          no_donation_nag = true;
          enforce_permissions = true;
        };

        general = {
          resize_on_border = true;
          no_focus_fallback = true;
          layout = "hy3";
          allow_tearing = true;

          snap.enabled = true;
        };

        misc = {
          animate_manual_resizes = false;
          animate_mouse_windowdragging = false;

          focus_on_activate = true;
          disable_hyprland_logo = true;
          force_default_wallpaper = 0;
          allow_session_lock_restore = true;

          initial_workspace_tracking = 1;

          middle_click_paste = false;
        };
      };

      layer_rule =
        #region No Animations
        (pipe
          [
            "walker"
            "selection"
            "overview"
            "anyrun"
            "gauntlet"
            "indicator.*"
            "osk"
            "hyprpicker"
            "noanim"
          ]
          [
            (map (ns: {
              match = {
                namespace = ns;
              };
              no_anim = true;
            }))
          ]
        )
        #endregion
        ++ [
          {
            match = {
              namespace = "sideleft.*";
            };
            animation = "slide top";
          }
          {
            match = {
              namespace = "sideright.*";
            };
            animation = "slide top";
          }
          {
            match = {
              namespace = "session";
            };
            blur = true;
          }
        ]
        #region Blur & Ignore Alpha
        ++ (pipe
          [
            "bar"
            "corner.*"
            "dock"
            "indicator.*"
            "indicator*"
            "overview"
            "cheatsheet"
            "sideright"
            "sideleft"
            "osk"
          ]
          [
            (map (ns: [
              {
                match = {
                  namespace = ns;
                };
                blur = true;
              }
              {
                match = {
                  namespace = ns;
                };
                ignore_alpha = 0.6;
              }
            ]))
            flatten
          ]
        );
      #endregion

      # Mouse drag/resize via direct Lua hl.bind() with _args
      bind = [
        {
          _args = [
            "SUPER + mouse:272"
            (generators.mkLuaInline "hl.dsp.window.drag()")
          ];
        }
        {
          _args = [
            "SUPER + mouse:273"
            (generators.mkLuaInline "hl.dsp.window.resize()")
          ];
        }
      ];
    };
  };
}
