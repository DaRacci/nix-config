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

  home.file.".local/bin/wlprop".source = "${pkgs.wlprop}/bin/wlprop";

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
      ++ (
        builtins.readDir ./lua/looks
        |> lib.filterAttrs (_: type: type == "regular")
        |> lib.mapAttrsToList (n: _: ./lua/looks/${n})
      );
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
