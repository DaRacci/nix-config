{
  config,
  pkgs,
  lib,
  ...
}:
let
  getDirectionChar = key: builtins.elemAt (lib.stringToCharacters key) 0;

  uwsmExec = command: [
    "exec"
    "${lib.getExe' pkgs.uwsm "uwsm-app"} -s a -- ${command}"
  ];
in
{
  wayland.windowManager.hyprland = {
    custom-settings = {
      bind =
        [
          {
            keybind = [
              "SUPER"
              "ALT"
              "RIGHT"
            ];
            action = [
              "movecurrentworkspacetomonitor"
              "+1"
            ];
          }
          {
            keybind = [
              "SUPER"
              "ALT"
              "LEFT"
            ];
            action = [
              "movecurrentworkspacetomonitor"
              "-1"
            ];
          }
          {
            keybind = [
              "SUPER"
              "SHIFT"
              "S"
            ];
            action = [
              "movetoworkspace"
              "special"
            ];
          }
          {
            keybind = [
              "SUPER"
              "S"
            ];
            action = [ "togglespecialworkspace" ];
          }
        ]
        #region Directional focus & movement
        ++ (builtins.concatLists (
          builtins.map (key: [
            {
              keybind = [
                "SUPER"
                "SHIFT"
                key
              ];
              action = [
                "hy3:movewindow"
                (lib.toLower (getDirectionChar key))
              ];
            }
            {
              keybind = [
                "SUPER"
                key
              ];
              action = [
                "hy3:movefocus"
                (lib.toLower (getDirectionChar key))
              ];
            }
          ]) lib.mine.keys.directionalKeys
        ))
        #endregion
        #region Exec commands
        ++ [
          {
            keybind = [
              "SUPER"
              "T"
            ];
            action = uwsmExec (lib.getExe config.programs.alacritty.package);
          }
          {
            keybind = [
              "SUPER"
              "F"
            ];
            action = uwsmExec (lib.getExe config.programs.firefox.package);
          }
          {
            keybind = [
              "SUPER"
              "E"
            ];
            action = uwsmExec (lib.getExe pkgs.nautilus);
          }
        ]
        #endregion
        #region Workspace keybinds
        ++ (builtins.concatLists (
          builtins.genList (
            x:
            let
              workspace = builtins.toString (x + 1 - ((x + 1) / 10) * 10);
            in
            [
              {
                keybind = [
                  "SUPER"
                  workspace
                ];
                action = [
                  "workspace"
                  (toString (x + 1))
                ];
              }
              {
                keybind = [
                  "SUPER"
                  "SHIFT"
                  workspace
                ];
                action = [
                  "movetoworkspace"
                  (toString (x + 1))
                ];
              }
            ]
          ) 10
        ))
      #endregion
      ;
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
        focus_preferred_method = 0;
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

      bind = [
        # (binding mainMod "b" "exec" "${lib.getExe pkgs.hdrop} -f -b ${lib.getExe pkgs.overskride}")
      ];
    };
  };
}
