{
  config,
  pkgs,
  lib,
  ...
}:
let
  getDirectionChar = key: builtins.elemAt (lib.stringToCharacters key) 0;
  getDirectionXYInt =
    key: int:
    let
      dirInt =
        if key == "UP" || key == "RIGHT" then
          -int
        else if key == "DOWN" || key == "LEFT" then
          int
        else
          throw "Invalid direction key provided, expected UP, DOWN, LEFT or RIGHT";
    in
    if key == "UP" || key == "DOWN" then "0 ${toString dirInt}" else "${toString dirInt} 0";

  uwsmExec = command: [
    "exec"
    "${lib.getExe' pkgs.uwsm "uwsm-app"} -s a -- ${command}"
  ];

  programShortcuts = {
    "SUPER+T" = lib.getExe config.programs.alacritty.package;
    "SUPER+F" = lib.getExe config.programs.firefox.package;
    "SUPER+SHIFT+E" = "${lib.getExe pkgs.nautilus} --new-window";
  };
in
{
  wayland.windowManager.hyprland = {
    custom-settings = {
      bind = {
        "SUPER+ALT+RIGHT" = [
          "movecurrentworkspacetomonitor"
          "+1"
        ];
        "SUPER+ALT+LEFT" = [
          "movecurrentworkspacetomonitor"
          "-1"
        ];

        #region Graveyard
        "SUPER+SHIFT+S" = [
          "movetoworkspace"
          "special"
        ];
        "SUPER+S" = [ "togglespecialworkspace" ];
        #endregion

        "CTRL+ALT+DELETE" = [
          "exec"
          "uwsm stop"
        ];

        #region Media
        XF86AudioRaiseVolume = [
          "exec"
          "${lib.getExe' pkgs.wireplumber "wpctl"} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ];
        XF86AudioLowerVolume = [
          "exec"
          "${lib.getExe' pkgs.wireplumber "wpctl"} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"
        ];
        XF86AudioMute = [
          "exec"
          "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ];
        XF86AudioMicMute = [
          "exec"
          "${lib.getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ];
        #endregion
      }
      #region Focus & Movement
      // (lib.pipe lib.mine.keys.directionalKeys [
        (builtins.map (key: [
          (lib.nameValuePair "SUPER+SHIFT+${key}" [
            "hy3:movewindow"
            (lib.toLower (getDirectionChar key))
          ])
          (lib.nameValuePair "SUPER+${key}" [
            "hy3:movefocus"
            (lib.toLower (getDirectionChar key))
          ])
        ]))
        builtins.concatLists
        lib.listToAttrs
      ])
      #endregion
      #region Program Shortcuts
      // (builtins.mapAttrs (_: uwsmExec) programShortcuts)
      #endregion
      #region Workspaces
      // (lib.pipe 10 [
        (builtins.genList (
          x:
          let
            workspaceId = builtins.toString (x + 1 - ((x + 1) / 10) * 10);
          in
          {
            "SUPER+${workspaceId}" = [
              "workspace"
              (builtins.toString (x + 1))
            ];
            "SUPER+SHIFT+${workspaceId}" = [
              "movetoworkspace"
              (builtins.toString (x + 1))
            ];
          }
        ))
        lib.mergeAttrsList
      ])
      #endregion
      #region Media

      #endregion
      ;

      submaps = {
        resize = {
          enter = "ALT+R";
          reset = "ESCAPE";

          binds = lib.pipe lib.mine.keys.directionalKeys [
            (builtins.map (
              key:
              (lib.nameValuePair key {
                modifiers = lib.mine.hypr.types.bindModifier.repeat;
                action = [
                  "resizeactive"
                  (getDirectionXYInt key 50)
                ];
              })
            ))
            lib.listToAttrs
          ];
        };
      };
    };

    settings = {
      cursor = {
        no_warps = false;
        persistent_warps = true;
        warp_back_after_non_mouse_input = false;

        no_hardware_cursors = true;
        use_cpu_buffer = 2;

        inactive_timeout = 15;
        hide_on_key_press = true;
      };

      binds = {
        workspace_back_and_forth = true;
        allow_workspace_cycles = true;
        workspace_center_on = 1;
        focus_preferred_method = 1;
        movefocus_cycles_fullscreen = false;
        allow_pin_fullscreen = true;
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;

        touchpad = {
          natural_scroll = false;
        };

        sensitivity = 0;
        accel_profile = "flat";
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
      };

      misc = {
        key_press_enables_dpms = false;
        mouse_move_enables_dpms = true;
      };

      bind = [
        # (binding mainMod "b" "exec" "${lib.getExe pkgs.hdrop} -f -b ${lib.getExe pkgs.overskride}")
      ];
    };
  };
}
