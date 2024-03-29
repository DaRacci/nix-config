{ inputs, config, pkgs, lib, ... }: with lib; {
  imports = [
    ../../../../common/desktop/hyprland
    ./lock-screen.nix
    ./notification.nix
    ./pannel.nix
    ./runner.nix
    ./screenshot.nix
  ];

  wayland.windowManager.hyprland = {
    plugins = with inputs.hyprland-plugins.packages.${pkgs.system}; [
      borders-plus-plus
      hyprtrails
    ];

    extraConfig =
      let
        mod = "SUPER";

        animations = ''
          animations {
            enabled = yes
            bezier = wind, 0.05, 0.9, 0.1, 1.05
            bezier = winIn, 0.1, 1.1, 0.1, 1.1
            bezier = winOut, 0.3, -0.3, 0, 1
            bezier = liner, 1, 1, 1, 1
            animation = windows, 1, 6, wind, slide
            animation = windowsIn, 1, 6, winIn, slide
            animation = windowsOut, 1, 5, winOut, slide
            animation = windowsMove, 1, 5, wind, slide
            animation = border, 1, 1, liner
            animation = borderangle, 1, 30, liner, loop
            animation = fade, 1, 10, default
            animation = workspaces, 1, 5, wind
          }
        '';

        executions = let
          dbus-update-env = "${pkgs.dbus}/bin/dbus-update-activation-environment";
        in ''
          # ----------------- #
          # Environment Fixes #
          # ----------------- #
          exec-once = ${dbus-update-env} --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
          exec-once = ${dbus-update-env} --systemd --all
          exec-once = ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

          # ----------------- #
          # User Applications #
          # ----------------- #
          exec-once = ${pkgs.libsForQt5.polkit-kde-agent}/lib/polkit-kde-authentication-agent-1

          # ----------------- #
          #  Bar and Applets  #
          # ----------------- #
          exec-once = ${config.programs.waybar.package}/bin/waybar
          exec-once = ${pkgs.blueman}/bin/blueman
          exec-once = ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator

          # ----------------- #
          #      Daemons      #
          # ----------------- #
          exec-once = ${config.programs.mako.package}/bin/mako
          exec-once = ${pkgs.unstable.hypridle}/bin/hypridle
          
          # ----------------- #
          #     Wallpaper     #
          # ----------------- #
          exec-once = ${pkgs.swww}/bin/swww init
          exec-once = ${pkgs.writeShellScriptBin "sww-random-wallpaper" ''
            export SWWW_TRANSITION=random
            export SWWW_TRANSITION_STEP=2
            export SWWW_TRANSITION_DURATION=2
            export SWWW_TRANSITION_FPS=165
            export SWWW_TRANSITION_ANGLE=90
            export SWWW_TRANSITION_POS=left
            export SWWW_TRANSITION_BEZIER=.07,.56,1,.25

            # This controls (in seconds) when to switch to the next image
            INTERVAL=10
            DIRECTORY=$HOME/Pictures/Wallpapers

            while true; do
              find "$DIRECTORY" | while read -r img; do
                echo "$((RANDOM % 1000)):$img"
              done | sort -n | cut -d':' -f2- | while read -r img; do
                ${getExe pkgs.swww} img "$img"
                sleep $INTERVAL
              done
            done
          ''}/bin/sww-random-wallpaper
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
          env = XDG_SESSION_DESKTOP,Hyprland
          env = QT_QPA_PLATFORM,wayland
          #env = QT_STYLE_OVERRIDE,kvantum
          env = QT_QPA_PLATFORMTHEME,qt5ct
          env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
          env = QT_AUTO_SCREEN_SCALE_FACTOR,1
        '';

        input = ''
          input {
            kb_layout = us
            follow_mouse = 3

            touchpad {
                natural_scroll = no
            }

            sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
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

              bind=,escape,submap,reset 
              submap=reset
            '';
          };

          global = {
            shortcuts = ''
              bind = CONTROL,ESCAPE,exec,killall waybar || ${config.programs.waybar.package}/bin/waybar

              # TODO Allow customising
              bind = ${mod},T,exec,${pkgs.alacritty}/bin/alacritty
              bind = ${mod},E,exec,${pkgs.gnome.nautilus}/bin/nautilus
              bind = ${mod},F,exec,${config.programs.firefox.package}/bin/firefox

              bind = CTRL_SHIFT,ESCAPE,exec,${config.programs.bottom.package}/bin/bottom

              # TODO - Screenshot sound
              bind=,Print,exec,${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp -o -r -c '#ff0000ff')" - | ${pkgs.unstable.satty}/bin/satty --filename - --fullscreen --output-filename ~/Pictures/Screenshots/$(date '+%Y/%m/%d/Screenshot_%Y%m%d_%H%M%S.png')
            '';

            audio = ''
              bindel=,XF86AudioRaiseVolume,exec,${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
              bindel=,XF86AudioLowerVolume,exec,${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
              bindl=,XF86AudioMute,exec,${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
              bindl=,XF86AudioMicMute,exec,${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

              bind=,XF86AudioPlay,exec,${pkgs.playerctl}/bin/playerctl play-pause
              bind=,XF86AudioPause,exec,${pkgs.playerctl}/bin/playerctl play-pause
              bind=,XF86AudioNext,exec,${pkgs.playerctl}/bin/playerctl next
              bind=,XF86AudioPrev,exec,${pkgs.playerctl}/bin/playerctl previous
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
              bind = ${mod},Q,killactive                # Kill active window
              bind = ${mod},SPACE,fullscreen            # Toggle fullscreen for the active window
              bind = ${mod} SHIFT,space,togglefloating  # Toggle floating for the active window

              bindm = ${mod},mouse:272,moveactive        # Move active window
              bindm = ${mod},mouse:273,resizeactive      # Resize active window
            '';

            session = ''
              bind = CTRL_ALT,DELETE,exit        # Exit session
              # bind = ${mod},SHIFT,DELETE,restart # Restart session
            '';

            workspace = ''
              # Move workspaces between monitors
              bind = ${mod}_ALT,RIGHT,movecurrentworkspacetomonitor,+1
              bind = ${mod}_ALT,LEFT,movecurrentworkspacetomonitor,-1

              # Graveyard
              bind=SUPER_SHIFT,S,movetoworkspace,special
              bind=SUPER,S,togglespecialworkspace,
            '';

            workspaces = builtins.concatStringsSep "\n" (builtins.genList
              (x:
                let
                  workspace = builtins.toString (x + 1 - ((x + 1) / 10) * 10);
                in
                ''
                  bind = ${mod}, ${workspace}, workspace, ${toString (x + 1)}
                  bind = ${mod} SHIFT, ${workspace}, movetoworkspace, ${toString (x + 1)}
                '') 10);
          };
        };

        theme = ''
          decoration {
            rounding = 12

            active_opacity = 1
            inactive_opacity = 0.8
            #full_opacity = 1

            drop_shadow = true
            shadow_range = 8
            shadow_render_power = 2
            col.shadow = rgba(00000044)

            dim_inactive = true
            dim_strength = 0.1

            blur {
              enabled = true
              size = 8
              passes = 3
              new_optimizations = on
              noise = 0.01
              contrast = 0.9
              brightness = 0.8
            }
          }

          general {
            col.active_border = rgba(eae0e445)
            col.inactive_border = rgba(9a8d9533)
          }

          plugin {
            borders-plus-plus {
                add_borders = 1 # 0 - 9

                # you can add up to 9 borders
                col.border_1 = rgb(ffffff)
                col.border_2 = rgb(2222ff)

                # -1 means "default" as in the one defined in general:border_size
                border_size_1 = 10
                border_size_2 = -1

                # makes outer edges match rounding of the parent. Turn on / off to better understand. Default = on.
                natural_rounding = yes
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
        '';
      in
      builtins.concatStringsSep "\n" ([
        env

        theme
        animations
        
        executions
        monitors
        other
      ] ++ builtins.attrValues bindings.global ++ builtins.attrValues bindings.submaps);
  };
}
