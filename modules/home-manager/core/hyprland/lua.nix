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

  # Extract all @PLACEHOLDER@ names from a file content as a list of strings (without @ signs).
  # Used to scope variable substitution to only placeholders actually present in each file.
  parsePlaceholders =
    fileContent:
    builtins.filter (s: s != null) (
      map (m: builtins.elemAt m 0) (
        builtins.split "@([A-Za-z0-9_-]+)@" fileContent |> builtins.filter builtins.isList
      )
    );

  # Build a substitution attrset for a single module: intersect file placeholders with merged variables.
  # Errors if file references a placeholder that isn't in merged variables.
  varsForModule =
    modulePath:
    let
      fileContent = builtins.readFile modulePath;
      referenced = parsePlaceholders fileContent;
      missing = builtins.filter (name: !cfg.variables ? "${name}") referenced;
    in
    if missing != [ ] then
      builtins.throw "hyprland lua: ${baseNameOf modulePath} references placeholders [${concatStringsSep ", " missing}] not found in config.wayland.windowManager.hyprland.custom-settings.lua.variables"
    else
      lib.filterAttrs (name: _: builtins.elem name referenced) cfg.variables;

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
      default =
        builtins.readDir ./lua
        |> builtins.attrNames
        |> builtins.filter (file: builtins.match ".*\\.lua$" file != null)
        |> map (file: ./lua/${file});
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
            content = pkgs.replaceVars modulePath (varsForModule modulePath);
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

        cursorSize = toString config.stylix.cursor.size;
      };
    };
  };
}
