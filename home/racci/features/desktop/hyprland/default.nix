# TODO - Game mode that disables fancy animations and pauses swww-random-wallpaper
# TODO Show me the key integration for placement size & quick launching
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
    #endregion
  };

  wayland.windowManager.hyprland = {
    systemd.enable = false;

    plugins = with pkgs.hyprlandPlugins; [
      hy3
      # hyprfocus
      hypr-dynamic-cursors
    ];

    custom-settings.permission.plugin =
      with pkgs.hyprlandPlugins;
      [
        hy3
        hypr-dynamic-cursors
      ]
      |> lib.map (plugin: "${plugin}/lib/lib${plugin.pname}.so");

    settings = {
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

      layerrule = [
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
        animate_manual_resizes = false;
        animate_mouse_windowdragging = false;

        focus_on_activate = true;
        disable_hyprland_logo = true;
        force_default_wallpaper = 0;
        new_window_takes_over_fullscreen = 2;
        allow_session_lock_restore = true;

        initial_workspace_tracking = 1;

        middle_click_paste = false;
      };

      plugins = {
        # hy3 = {
        #   no_gaps_when_only = 1;
        #   tab_first_window = false;

        #   autotile = {
        #     enable = true;
        #   };
        # };
      };
    };

    extraConfig =
      let
        mod = "SUPER";

        bindings = {
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
          };
        };
      in
      builtins.concatStringsSep "\n" (builtins.attrValues bindings.global);
  };
}
