# TODO - Game mode that disables fancy animations and pauses swww-random-wallpaper
# TODO Show me the key integration for placement size & quick launching
{
  flake,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
{
  imports = [
    "${flake}/home/racci/features/desktop/common"
    "${flake}/home/shared/desktop/hyprland"

    ./actions.nix
    ./input.nix
    ./lock-suspend.nix
    ./looks.nix
    ./menus
    ./nvidia.nix
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

  wayland.windowManager.hyprland = {
    systemd.enable = false;

    plugins = with pkgs.hyprlandPlugins; [
      hy3
      # hyprfocus
      hypr-dynamic-cursors
    ];

    custom-settings = {
      windowrule = [
        {
          matcher.title = "^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$";
          rule = {
            keepaspectratio = true;
            float = true;
            pin = true;
            opacity = 1.0;
            size = "25%";
            move = {
              x = "73%";
              y = "72%";
            };
          };
        }
        {
          matcher = [
            { title = "^(Assetto Corsa)$"; }
            { title = "^(AC2)$"; }
          ];
          rule = {
            float = true;
            center = true;
            norounding = true;
            opacity = 1.0;
            size = "7680x1440";
          };
        }
        {
          matcher = [
            { class = "^(file_progress)$"; }
            { class = "^(confirm)$"; }
            { class = "^(dialog)$"; }
            { class = "^(download)$"; }
            { class = "^(notification)$"; }
            { class = "^(error)$"; }
            { class = "^(confirmreset)$"; }
            { title = "^(branchdialog)$"; }
            { title = "^(Confirm to replace files)$"; }
            { title = "^(File Operation Progress)$"; }
            { class = "^(org.pulseaudio.pavucontrol)$"; }
          ];
          rule.float = true;
        }
        {
          matcher = [
            { title = "^(Steam Settings)(.*)$"; }
            { title = "^(Open File)(.*)$"; }
            { title = "^(Select a File)(.*)$"; }
            { title = "^(Choose wallpaper)(.*)$"; }
            { title = "^(Open Folder)(.*)$"; }
            { title = "^(Save As)(.*)$"; }
            { title = "^(Library)(.*)$"; }
            { title = "^(File Upload)(.*)$"; }
          ];
          rule = {
            center = true;
            float = true;
          };
        }
        {
          matcher.class = "(steam_app)";
          rule.immediate = true;
        }
        {
          matcher.class = "^(org.pulseaudio.pavucontrol)$";
          rule = {
            float = true;
            size = "33%";
            move = {
              x = "33%";
              y = 50;
            };
          };
        }
      ];
    };

    settings = {
      debug.disable_logs = true;

      render = {
        direct_scanout = 2;
      };

      monitor = lib.mkAfter [
        ", preferred, auto, 1" # Fallback Rule
      ];

      general = {
        resize_on_border = true;
        no_focus_fallback = true;
        layout = "hy3"; # "dwindle";
        allow_tearing = true;

        snap.enabled = true;
      };

      dwindle = {
        preserve_split = true;
        smart_split = true;
        smart_resizing = true;
        pseudotile = true;
      };

      env = [
        #region Toolkit Backends
        "GTK_BACKEND,wayland,x11"
        "QT_QPA_PLATFORM,wayland;xcb"
        # "SDL_VIDEODRIVER,wayland" # Breaks osu! hardware acceleration
        "CLUTTER_BACKEND,wayland"
        #endregion
      ];

      layerrule =
        [
          "xray 1, .*"
          #region No Animations
        ]
        ++ (trivial.pipe
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
            (map (layer: "noanim, ${layer}"))
            #endregion
            #region Ags
          ]
        )
        ++ [
          "animation slide top, sideleft.*"
          "animation slide top, sideright.*"
          "blur, session"
        ]
        ++ (trivial.pipe
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
            (map (layer: [
              "blur, ${layer}"
              "ignorealpha 0.6, ${layer}"
            ]))
            flatten
            #endregion
          ]
        );

      misc = {
        # vfr = true;
        # vrr = true;

        animate_manual_resizes = false;
        animate_mouse_windowdragging = false;

        focus_on_activate = true;
        disable_hyprland_logo = true;
        force_default_wallpaper = 0;
        new_window_takes_over_fullscreen = 2;
        allow_session_lock_restore = true;

        initial_workspace_tracking = 2;

        middle_click_paste = false;
      };
    };

    extraConfig =
      let
        mod = "SUPER";

        bindings = {
          submaps = {
            resize = ''
              bind=ALT,R,submap,resize
              submap=resize

              binde=,right,resizeactive,10 0
              binde=,left,resizeactive,-10 0
              binde=,up,resizeactive,0 -10
              binde=,down,resizeactive,0 10

              binde=,right,resizeactive,50 0
              binde=,left,resizeactive,-50 0
              binde=,up,resizeactive,0 -50
              binde=,down,resizeactive,0 50

              bind=,escape,submap,reset
              bind=,enter,submap,reset
              submap=reset
            '';
          };

          global = {
            audio =
              let
                wpctl = "${pkgs.wireplumber}/bin/wpctl";
                playerctl = getExe config.services.playerctld.package;
              in
              ''
                bindel=,XF86AudioRaiseVolume,exec,${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
                bindel=,XF86AudioLowerVolume,exec,${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-
                bindl=,XF86AudioMute,exec,${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle
                bindl=,XF86AudioMicMute,exec,${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle

                bind=,XF86AudioPause,exec,${playerctl} play-pause
                bind=,XF86AudioPlay,exec,${playerctl} play-pause
                bind=,XF86AudioNext,exec,${playerctl} next
                bind=,XF86AudioPrev,exec,${playerctl} previous
              '';

            window = ''
              bind = ${mod},Q,killactive                # Kill active window
              bind = ${mod},SPACE,fullscreen            # Toggle fullscreen for the active window
              bind = ${mod} SHIFT,space,togglefloating  # Toggle floating for the active window

              bindm = ${mod}, mouse:272, movewindow     # Move active window
              bindm = ${mod}, mouse:273, resizewindow   # Resize active window
            '';

            session = ''
              bind = CTRL_ALT,DELETE,exit           # Exit session
            '';
          };
        };
      in
      builtins.concatStringsSep "\n" (
        builtins.attrValues bindings.global ++ builtins.attrValues bindings.submaps
      );
  };
}
