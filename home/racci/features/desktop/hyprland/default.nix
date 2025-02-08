# TODO - Game mode that disables compositor and pauses swww-random-wallpaper
{
  flake,
  inputs,
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

    ./ags.nix
    ./actions.nix
    ./clipboard.nix
    ./lock-suspend.nix
    ./menus.nix
    ./notification.nix
    ./panel.nix
    ./polkit.nix
    ./rofi.nix
    ./runner.nix
  ];

  xdg.desktopEntries."org.gnome.Settings" = {
    name = "Settings";
    comment = "Gnome Control Center";
    icon = "${pkgs.gnome-control-center}/share/icons/hicolor/scalable/apps/org.gnome.Settings-system-symbolic.svg";
    # Force to the WiFi page as some pages crash and reopens to the last page visited on startup.
    exec = "env XDG_CURRENT_DESKTOP=gnome ${lib.getExe pkgs.gnome-control-center} -v wifi";
    categories = [ "X-Preferences" ];
    terminal = false;
  };

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

  wayland.windowManager.hyprland = {
    systemd.enable = false;

    plugins =
      with pkgs.hyprlandPlugins;
      with inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system};
      [
        hyprfocus
        borders-plus-plus
        inputs.hyprland-dynamic-cursors.packages.${pkgs.stdenv.hostPlatform.system}.hypr-dynamic-cursors
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
      ];
    };

    settings = {
      monitor = [
        "DP-2,  2560x1440@165,  0x0,        1, vrr, 1" # Center Monitor
        "DP-1,  2560x1440@144,  auto-left,  1, vrr, 1" # Left Monitor
        "DP-3,  2560x1440@144,  auto-right, 1, vrr, 1" # Right Monitor
        ",      preferred,      auto,       1" # Fallback Rule
      ];

      animations = {
        enabled = "yes";

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
        rounding = 20;

        blur = {
          enabled = true;
          xray = true;
          special = false;
          new_optimizations = true;
          size = 14;
          passes = 4;
          brightness = 1;
          noise = 0.01;
          contrast = 1;
          popups = true;
          popups_ignorealpha = 0.6;
        };

        #region Shadows
        shadow = {
          enabled = true;
          range = 20;
          render_power = 4;
          ignore_window = true;
          offset = "0 2";
        };
        #endregion

        #region Dim
        dim_inactive = false;
        dim_strength = 0.1;
        dim_special = 0;
        #endregion
      };

      # workspace = [
      #   "workspace = w[t1], gapsout:0, gapsin:0, border: 0, rounding:0"
      #   "workspace = w[tg1], gapsout:0, gapsin:0, border: 0, rounding:0"
      # ];
      #endregion

      general = {
        gaps_in = 4;
        gaps_out = 5;
        gaps_workspaces = 50;
        border_size = 1;

        resize_on_border = true;
        no_focus_fallback = true;
        layout = "dwindle";
        allow_tearing = true;
      };

      dwindle = {
        preserve_split = true;
        smart_split = true;
        smart_resizing = true;
        pseudotile = true;
      };

      exec-once = [
        "gnome-keyring-daemon --start --components=secrets"

        # ----------------- #
        #  Bar and Applets  #
        # ----------------- #
        "${lib.getExe' pkgs.blueman "blueman-tray"}"
        "${lib.getExe pkgs.networkmanagerapplet} --indicator"
      ];

      cursor = {
        no_warps = false;
        persistent_warps = true;
        no_hardware_cursors = true;
      };

      binds = {
        allow_workspace_cycles = true;
      };

      bind = [
        # (binding mainMod "b" "exec" "${lib.getExe pkgs.hdrop} -f -b ${lib.getExe pkgs.overskride}")
      ];

      env = [
        #region NVIDIA
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "LIBVA_DRIVER_NAME,nvidia"
        "__GL_GSYNC_ALLOWED,1"
        "__GL_VRR_ALLOWED,1"
        #endregion

        #region XDG
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
        #endregion

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
        vfr = true;
        vrr = true;

        mouse_move_enables_dpms = 1;
        key_press_enables_dpms = 1;

        animate_manual_resizes = false;
        animate_mouse_windowdragging = false;
        enable_swallow = false;
        swallow_regex = "(foot|kitty|alacritty|Alacritty)";

        focus_on_activate = true;
        disable_hyprland_logo = true;
        force_default_wallpaper = 0;
        new_window_takes_over_fullscreen = 2;
        allow_session_lock_restore = true;

        initial_workspace_tracking = false;
      };

      plugin = {
        overview = {
          centerAligned = true;
          hideTopLayers = true;
          hideOverlayLayers = true;
          showNewWorkspace = true;
          exitOnClick = true;
          exitOnSwitch = true;
          drawActiveWorkspace = true;
          reverseSwipe = true;
        };

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
          mode = "rotate";
          threshold = 2;

          rotate = {
            length = config.stylix.cursor.size;
            offset = 0.0;
          };

          shake = {
            enabled = true;
            nearest = false;
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

        hyprexpo = {
          columns = 3;
          gap_size = 5;
          bg_col = "rgb(000000)";
          workspace_method = "first 1"; # [center/first] [workspace] e.g. first 1 or center m+1

          enable_gesture = true; # laptop touchpad, 4 fingers
          gesture_distance = 300; # how far is the "max"
          gesture_positive = false;
        };
      };
    };

    extraConfig =
      let
        mod = "SUPER";

        input = ''
          input {
            kb_layout = us
            follow_mouse = 1

            touchpad {
                natural_scroll = no
            }

            sensitivity = 0
            accel_profile = flat
          }

          gestures {
            workspace_swipe = true
            workspace_swipe_fingers = 3
          }
        '';

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
            applications = ''
              # TODO Allow customising
              bind = ${mod},T,exec,${getExe config.programs.alacritty.package}
              bind = ${mod},E,exec,${pkgs.nautilus}/bin/nautilus
              bind = ${mod},F,exec,${getExe config.programs.firefox.finalPackage}
            '';

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

            focus = ''
              bind = ${mod},left,movefocus,l
              bind = ${mod},right,movefocus,r
              bind = ${mod},up,movefocus,u
              bind = ${mod},down,movefocus,d
            '';

            movement = ''
              bind = ${mod} SHIFT,left,movewindow,l
              bind = ${mod} SHIFT,right,movewindow,r
              bind = ${mod} SHIFT,up,movewindow,u
              bind = ${mod} SHIFT,down,movewindow,d
            '';

            window = ''
              bind = ${mod} SHIFT, left, movewindow, l
              bind = ${mod} SHIFT, right, movewindow, r
              bind = ${mod} SHIFT, up, movewindow, u
              bind = ${mod} SHIFT, down, movewindow, d

              bind = ${mod},Q,killactive                # Kill active window
              bind = ${mod},SPACE,fullscreen            # Toggle fullscreen for the active window
              bind = ${mod} SHIFT,space,togglefloating  # Toggle floating for the active window

              bindm = ${mod}, mouse:272, movewindow     # Move active window
              bindm = ${mod}, mouse:273, resizewindow   # Resize active window
            '';

            session = ''
              bind = CTRL_ALT,DELETE,exit           # Exit session
            '';

            workspace = ''
              # Move workspaces between monitors
              bind = ${mod}_ALT,RIGHT,movecurrentworkspacetomonitor,+1
              bind = ${mod}_ALT,LEFT,movecurrentworkspacetomonitor,-1

              # Graveyard
              bind=SUPER_SHIFT,S,movetoworkspace,special
              bind=SUPER,S,togglespecialworkspace,
            '';

            workspaces = builtins.concatStringsSep "\n" (
              builtins.genList (
                x:
                let
                  workspace = builtins.toString (x + 1 - ((x + 1) / 10) * 10);
                in
                ''
                  bind = ${mod}, ${workspace}, workspace, ${toString (x + 1)}
                  bind = ${mod} SHIFT, ${workspace}, movetoworkspace, ${toString (x + 1)}
                ''
              ) 10
            );
          };
        };

        theme = ''
          decoration {
            active_opacity = 0.95
            inactive_opacity = 0.95
            fullscreen_opacity = 1

            # shadow_offset = 0.2
          }

          general {
            col.active_border = rgba(eae0e445)
            col.inactive_border = rgba(9a8d9533)
          }

          plugin {
            # borders-plus-plus {
            #     add_borders = 1 # 0 - 9

            #     # you can add up to 9 borders
            #     col.border_1 = rgb(ffffff)
            #     col.border_2 = rgb(2222ff)

            #     # -1 means "default" as in the one defined in general:border_size
            #     border_size_1 = 10
            #     border_size_2 = -1

            #     # makes outer edges match rounding of the parent. Turn on / off to better understand. Default = on.
            #     natural_rounding = yes
            # }

            autotile {
              enable = false
            }
          }

          windowrulev2 = bordercolor rgba(ffabf1AA) rgba(ffabf177),pinned:1
        '';
      in
      builtins.concatStringsSep "\n" (
        [
          input
          theme
        ]
        ++ builtins.attrValues bindings.global
        ++ builtins.attrValues bindings.submaps
      );
  };
}
