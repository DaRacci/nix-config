{
  self,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    "${self}/home/racci/features/desktop/common"
    "${self}/home/shared/desktop/hyprland"

    ./actions.nix
    ./lock-suspend.nix
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
    custom-settings.lua = {
      enable = true;
      luaModules = [
        ./lua/default.lua
        ./lua/display.lua
      ]
      ++ (builtins.readDir ./lua/looks |> lib.filterAttrs (_: type: type == "regular") |> lib.mapAttrsToList (n: _: ./lua/looks/${n}));
      luaExtras = [
        ./lua/helpers
      ];
    };

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
  };
}
