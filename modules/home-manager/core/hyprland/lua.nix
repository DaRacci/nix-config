{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    mapAttrsToList
    listToAttrs
    concatStringsSep
    nameValuePair
    getExe
    getExe'
    ;
  inherit (types)
    listOf
    attrsOf
    nullOr
    path
    str
    ;
  cfg = config.wayland.windowManager.hyprland.custom-settings.lua;
in
{
  options.wayland.windowManager.hyprland.custom-settings.lua = {
    enable = mkEnableOption "Pure Lua configuration files for Hyprland, with a hint of nix substitution magic.";

    variables = mkOption {
      type = attrsOf (nullOr str);
      default = { };
      description = ''
        Variables to substitute in Lua files.
        Each key "foo" replaces @foo@ in source files with the value.
      '';
    };

    luaModules = mkOption {
      type = listOf path;
      default = [
        ./lua/binds.lua
      ];
      description = ''
        Lua modules to load in the main init.lua file.
        Each module is a path to a Lua file, which will be copied to the config directory and required in init.lua.
        Each module will have variables substituted according to the "variables" option, so you can use that to inject paths to nix packages or other dynamic values.
      '';
    };

    applicationBinds = mkOption {
      type = attrsOf str;
      default = { };
      description = ''
        Application binds to generate in Lua config.
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.luaModules != [ ]) {
    wayland.windowManager.hyprland = {
      extraLuaFiles =
        cfg.luaModules
        |> map (
          modulePath:
          nameValuePair (baseNameOf modulePath) {
            content = pkgs.replaceVars modulePath cfg.variables;
            autoLoad = true;
          }
        )
        |> listToAttrs;
      custom-settings.lua.variables = {
        applicationBinds = "{ ${
          cfg.applicationBinds
          |> mapAttrsToList (
            bind: command: "{ bind = ${builtins.toJSON bind}, command = ${builtins.toJSON command} }"
          )
          |> concatStringsSep ", "
        } }";

        playerctl = getExe pkgs.playerctl;
        wpctl = getExe' pkgs.wireplumber "wpctl";
        zenity = getExe pkgs.zenity;
        hyprshutdown = getExe pkgs.hyprshutdown;
        uwsmApp = getExe' pkgs.uwsm "uwsm-app";

        DEFAULT_AUDIO_SINK = null;
        DEFAULT_AUDIO_SOURCE = null;
      };
    };
  };
}
