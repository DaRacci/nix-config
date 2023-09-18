{ inputs, pkgs, ... }: {
  imports = [
    ../../../../common/desktop/hyprland
    ./mako.nix
  ];

  wayland.windowManager.hyprland = {
    plugins = [ inputs.hyprland-plugins.packages.${pkgs.system}.hyprbars ];

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

          # animations {
          #   bezier = myBezier, 0.05, 0.9, 0.1, 1.05
          #   animation = windows, 1, 5, myBezier
          #   animation = windowsOut, 1, 7, default, popin 80%
          #   animation = border, 1, 10, default
          #   animation = fade, 1, 7, default
          #   animation = workspaces, 1, 6, default
          # }
        '';

        daemons = ''
          exec-once = ${pkgs.libsForQt5.polkit-kde-agent}/lib/polkit-kde-authentication-agent-1
        '';

        monitors = ''
          monitor=DP-0,2560x1440@144,0x0,1
          monitor=DP-2,2560x1440@165,2560x0,0
          monitor=DP-4,2560x1440@144,5120x0,0
          monitor=,highrr,auto,1
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
              bind=${mod},RETURN,exec,${pkgs.alacritty}/bin/alacritty
            '';

            rofi = ''
              bind = $mainMod, A, exec, pkill rofi || ~/.config/hypr/scripts/rofilaunch.sh d    # launch desktop applications
              bind = $mainMod, tab, exec, pkill rofi || ~/.config/hypr/scripts/rofilaunch.sh w  # switch between desktop applications
              bind = $mainMod, R, exec, pkill rofi || ~/.config/hypr/scripts/rofilaunch.sh f    # browse system files
            '';

            audio = ''
              bind  = , XF86AudioMute, exec, ~/.config/hypr/scripts/volumecontrol.sh -o m # toggle audio mute
              bind  = , XF86AudioMicMute, exec, ~/.config/hypr/scripts/volumecontrol.sh -i m # toggle microphone mute
              binde = , XF86AudioLowerVolume, exec, ~/.config/hypr/scripts/volumecontrol.sh -o d # decrease volume
              binde = , XF86AudioRaiseVolume, exec, ~/.config/hypr/scripts/volumecontrol.sh -o i # increase volume
              bind  = , XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause
              bind  = , XF86AudioPause, exec, ${pkgs.playerctl}/bin/playerctl play-pause
              bind  = , XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next
              bind  = , XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous
            '';

            focus = ''
              bind = ${mod},left,movefocus,l
              bind = ${mod},right,movefocus,r
              bind = ${mod},up,movefocus,u
              bind = ${mod},down,movefocus,d
            '';

            window = ''
              bind = ${mod},Q,killactive                # Kill active window
              bind = ${mod},F,fullscreen                # Toggle fullscreen for the active window
              bind = ${mod} SHIFT,space,togglefloating  # Toggle floating for the active window

              bind = ${mod},mouse_left,moveactive       # Move active window

              # Move/Resize window with mouse
              bindm = ${mod},mouse:272,movewindow       # Move window
              bindm = ${mod},mouse:273,resizeactive     # Resize window
            '';

            # scratchpad = ''
            #   bind = ${mod} SHIFT,minus,grave,scratchpad,show
            #   bind = ${mod},grave,scratchpad,hide
            #   bind = ${mod},grave,scratchpad,toggle
            # '';

            session = ''
              bind = CTRL_ALT,DEL,exit        # Exit session
              bind = ${mod},SHIFT,DEL,restart # Restart session
            '';

            workspace = ''
              bind = ${mod},mouse_up,workspace,e+1
              bind = ${mod},mouse_down,workspace,e-1
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
            drop_shadow = yes
            shadow_range = 8
            shadow_render_power = 2
            col.shadow = rgba(00000044)

            dim_inactive = false

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

          plugin {
            hyprbars {
              bar_color = rgb(2a2a2a)
              bar_height = 28
              col_text = rgba(ffffffdd)
              bar_text_size = 11
              bar_text_font = Ubuntu Nerd Font
    
              buttons {
                button_size = 11
                col.maximize = rgba(ffffff11)
                col.close = rgba(ff111133)
              }
            }
          }
        '';

        other = ''
          misc {
            vrr = 1
          }
        '';
      in
      builtins.concatStringsSep "\n" ([
        animations
        daemons
        monitors
        theme
        other
      ] ++ builtins.attrValues bindings.global ++ builtins.attrValues bindings.submaps);
  };
}
