# TODO - Colour picker bind to SUPER + C (hyprpicker)
# TODO - Clipboard manager bind to SUPER + V (cliphist)
# TODO - Game mode that disables compositor and pauses swww-random-wallpaper
{ flake, config, pkgs, lib, ... }: with lib; {
  imports = [
    "${flake}/home/racci/features/desktop/common"
    "${flake}/home/shared/desktop/hyprland"

    # ./ags.nix
    ./clipboard.nix
    # ./lock-screen.nix
    ./notification.nix
    ./panel.nix
    ./polkit.nix
    ./rofi.nix
    ./runner.nix
    ./screenshot.nix
    ./wallpaper.nix
  ];

  xdg.desktopEntries."org.gnome.Settings" = {
    name = "Settings";
    comment = "Gnome Control Center";
    icon = "org.gnome.Settings";
    exec = "env XDG_CURRENT_DESKTOP=gnome ${pkgs.gnome.gnome-control-center}/bin/gnome-control-center";
    categories = [ "X-Preferences" ];
    terminal = false;
  };

  home.file.".local/bin/wlprop" = {
    executable = true;
    source = "${pkgs.writeShellApplication {
      name = "wlprop";
      runtimeInputs = with pkgs; [ hyprland jq slurp ];
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
    }}/bin/wlprop";
  };

  wayland.windowManager.hyprland = {
    settings = {
      exec-once = [
        "gnome-keyring-daemon --start --components=secrets"
      ];

      cursor = {
        no_warps = true;
      };

      binds = {
        allow_workspace_cycles = true;
      };

      bind =
        [
          # (binding mainMod "b" "exec" "${lib.getExe pkgs.hdrop} -f -b ${lib.getExe pkgs.overskride}")
        ];

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
          bar_text_size = 11;
          bar_text_font = "JetBrainsMono Nerd Font";

          buttons = {
            button_size = 0;
            "col.maximize" = "rgba(ffffff11)";
            "col.close" = "rgba(ff111133)";
          };
        };
      };

      windowrulev2 =
        let
          fl = target: regex: "float,${target}:^(${regex})$";
        in
        [
          #region Floating Windows
          (fl "title" "Picture-in-Picture")
          (fl "class" "file_progress")
          (fl "class" "confirm")
          (fl "class" "dialog")
          (fl "class" "download")
          (fl "class" "notification")
          (fl "class" "error")
          (fl "class" "confirmreset")
          (fl "title" "Open File")
          (fl "title" "branchdialog")
          (fl "title" "Confirm to replace files")
          (fl "title" "File Operation Progress")
          #endregion

          #region Pinning Windows (Keep between workspace changes)
          "pin, title:^(Picture-in-Picture)$"
          #endregion

          #region Opacity
          "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
          #endregion
        ];
    };

    extraConfig =
      let
        mod = "SUPER";

        animations = ''
          debug {
            disable_logs = false
          }

          animations {
            enabled = yes

            # bezier = wind, 0.05, 0.9, 0.1, 1.05
            # bezier = winIn, 0.1, 1.1, 0.1, 1.1
            # bezier = winOut, 0.3, -0.3, 0, 1
            # bezier = liner, 1, 1, 1, 1

            bezier = fluent_decel, 0, 0.2, 0.4, 1
            bezier = easeOutCirc, 0, 0.55, 0.45, 1
            bezier = easeOutCubic, 0.33, 1, 0.68, 1
            bezier = easeinoutsine, 0.37, 0, 0.63, 1

            animation = windowsIn, 1, 3, easeOutCubic, popin 30% # window open
            animation = windowsOut, 1, 3, fluent_decel, popin 70% # window close.
            animation = windowsMove, 1, 2, easeinoutsine, slide # everything in between, moving, dragging, resizing.

            # animation = windows, 1, 6, wind, slide
            # animation = windowsIn, 1, 6, winIn, slide
            # animation = windowsOut, 1, 5, winOut, slide
            # animation = windowsMove, 1, 5, qwind, slide

            # Fade
            animation = fadeIn, 1, 3, easeOutCubic  # fade in (open) -> layers and windows
            animation = fadeOut, 1, 2, easeOutCubic # fade out (close) -> layers and windows
            animation = fadeSwitch, 0, 1, easeOutCirc # fade on changing activewindow and its opacity
            animation = fadeShadow, 1, 10, easeOutCirc # fade on changing activewindow for shadows
            animation = fadeDim, 1, 4, fluent_decel # the easing of the dimming of inactive windows
            animation = border, 1, 2.7, easeOutCirc # for animating the border's color switch speed
            animation = borderangle, 1, 30, fluent_decel, once # for animating the border's gradient angle - styles: once (default), loop
            animation = workspaces, 1, 4, easeOutCubic, fade # styles: slide, slidevert, fade, slidefade, slidefadevert

            # animation = border, 1, 1, liner
            # animation = borderangle, 1, 30, liner, loop
            # animation = fade, 1, 10, default
            # animation = workspaces, 1, 5, wind
          }
        '';

        executions = ''
          # ----------------- #
          #  Bar and Applets  #
          # ----------------- #
          exec-once = ${pkgs.blueman}/bin/blueman
          exec-once = ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator
        '';

        monitors = ''
          monitor=DP-1,2560x1440@144,-2560x0,1
          monitor=DP-2,2560x1440@165,0x0,1
          monitor=DP-3,2560x1440@144,2560x0,1
          monitor=,highrr,auto,1
        '';

        env = ''
          env = LIBVA_DRIVER_NAME,nvidia
          env = XDG_SESSION_TYPE,wayland
          env = GBM_BACKEND,nvidia-drm
          env = __GLX_VENDOR_LIBRARY_NAME,nvidia
          env = WLR_NO_HARDWARE_CURSORS,1

          env = XDG_CURRENT_DESKTOP,Hyprland
          env = XDG_SESSION_TYPE,wayland
          # env = QT_QPA_PLATFORM,wayland
          #env = QT_STYLE_OVERRIDE,kvantum
          # env = QT_QPA_PLATFORMTHEME,qt5ct
          # env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
          # env = QT_AUTO_SCREEN_SCALE_FACTOR,1
        '';

        layout = ''
          dwindle {
            no_gaps_when_only = true
            force_split = 0
            special_scale_factor = 1.0
            split_width_multiplier = 1.0
            use_active_for_splits = true
            pseudotile = yes
            preserve_split = yes
          }

          master {
            new_status = true
            special_scale_factor = 1
            no_gaps_when_only = true
          }
        '';

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
              # bind = ${mod} CTRL, left, resizeactive, -80 0
              # bind = ${mod} CTRL, right, resizeactive, 80 0
              # bind = ${mod} CTRL, up, resizeactive, 0 -80
              # bind = ${mod} CTRL, down, resizeactive, 0 80
              # bind = ${mod} ALT, left, moveactive,  -80 0
              # bind = ${mod} ALT, right, moveactive, 80 0
              # bind = ${mod} ALT, up, moveactive, 0 -80
              # bind = ${mod} ALT, down, moveactive, 0 80

              bind = ${mod},Q,killactive                # Kill active window
              bind = ${mod},SPACE,fullscreen            # Toggle fullscreen for the active window
              bind = ${mod} SHIFT,space,togglefloating  # Toggle floating for the active window

              bindm = ${mod}, mouse:272, movewindow     # Move active window
              bindm = ${mod}, mouse:273, resizewindow   # Resize active window
            '';

            session = ''
              bind = CTRL_ALT,DELETE,exit        # Exit session
              # bind = ${mod},SHIFT,DELETE,restart # Restart session
            '';

            workspace = ''
              # Move workspaces between monitors
              bind = ${mod}_ALT,RIGHT,movecurrentworkspacetomonitor,-1
              bind = ${mod}_ALT,LEFT,movecurrentworkspacetomonitor,+1

              # Graveyard
              bind=SUPER_SHIFT,S,movetoworkspace,special
              bind=SUPER,S,togglespecialworkspace,
            '';

            workspaces = builtins.concatStringsSep "\n" (builtins.genList
              (x:
                let workspace = builtins.toString (x + 1 - ((x + 1) / 10) * 10); in ''
                  bind = ${mod}, ${workspace}, workspace, ${toString (x + 1)}
                  bind = ${mod} SHIFT, ${workspace}, movetoworkspace, ${toString (x + 1)}
                '') 10);
          };
        };

        theme = ''
          decoration {
            rounding = 5

            active_opacity = 0.95
            inactive_opacity = 0.95
            fullscreen_opacity = 1

            dim_inactive = false
            dim_strength = 0.1

            drop_shadow = true
            shadow_ignore_window = true
            # shadow_offset = 0.2
            shadow_range = 20
            shadow_render_power = 3
            col.shadow = rgba(00000055)

            blur {
              enabled = true
              new_optimizations = on
              xray = true

              size = 4
              passes = 2

              brightness = 1
              contrast = 1.3
              ignore_opacity = true
              noise = 0.011700

            }
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

            hy3 {
              no_gaps_when_only = 1
              node_collapse_policy = 2
              group_insert = 10
              tab_first_window = false

              tabs {
                height = 15
                padding = 5
                from_top = false
                rounding = 3
                render_text = true

                text_center = true
                text_font = JetBrainsMono Nerd Font
                text_height = 8
                text_padding = 3
              }
            }

            autotile {
              enable = false
            }
          }

          windowrulev2 = bordercolor rgba(ffabf1AA) rgba(ffabf177),pinned:1
        '';

        other = ''
          misc {
            vrr = 1
            disable_hyprland_logo = true
            disable_splash_rendering = true
            force_default_wallpaper = 0

            mouse_move_enables_dpms = 1
            key_press_enables_dpms = 1

            animate_manual_resizes = 1
            animate_mouse_windowdragging = 1

            focus_on_activate = true
          }

          env = WLR_DRM_NO_ATOMIC,1
        '';
      in
      builtins.concatStringsSep "\n" ([
        input
        layout
        env

        theme
        animations

        executions
        monitors
        other
      ] ++ builtins.attrValues bindings.global ++ builtins.attrValues bindings.submaps);
  };
}
