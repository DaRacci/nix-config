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
    splitString
    pathIsDirectory
    range
    take
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
      throw "hyprland lua: ${baseNameOf modulePath} references placeholders [${concatStringsSep ", " missing}] not found in config.wayland.windowManager.hyprland.custom-settings.lua.variables"
    else
      lib.filterAttrs (name: _: builtins.elem name referenced) cfg.variables;

  renderFile = modulePath: pkgs.replaceVars modulePath (varsForModule modulePath);

  # Find the closest 'lua' ancestor directory from a path.
  # Walks up the directory tree until it finds a component named 'lua'.
  findLuaAncestor =
    singlePath:
    let
      pathStr = toString singlePath;
      pathComponents = splitString "/" pathStr;
      # Find indices where component is "lua"
      luaIndices = builtins.filter (i: builtins.elemAt pathComponents i == "lua") (
        range 0 (builtins.length pathComponents - 1)
      );
    in
    # Take the last (closest) lua directory
    if luaIndices != [ ] then
      let
        closestIdx = builtins.elemAt luaIndices (builtins.length luaIndices - 1);
        # Only include components UP TO (not including) the lua directory
        ancestorComponents = take closestIdx pathComponents;
      in
      builtins.concatStringsSep "/" ancestorComponents
    else
      "";

  # Get relative path from base to target
  relPath =
    base: target:
    let
      baseStr = toString base;
      targetStr = toString target;
      baseLen = builtins.stringLength baseStr;
    in
    if builtins.substring 0 baseLen targetStr == baseStr then
      builtins.substring (baseLen + 1) (-1) targetStr
    else
      targetStr;
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
      default = [ ];
      description = ''
        Lua modules to load in the main init.lua file.
        Each module is a path to a Lua file, which will be copied to the config directory and required in init.lua.
        Each module will have variables substituted according to the "variables" option, so you can use that to inject paths to nix packages or other dynamic values.
      '';
    };

    luaExtras = mkOption {
      type = listOf path;
      default = [ ];
      description = ''
        Extra Lua files to copy to the config directory.
        These files will be copied to the config directory but not required in init.lua, so you can use them as libraries or for other purposes.

        Files defined here will respect parent directories and will be copied to the same relative path in the config directory.
        The absolute root of the directory tree will be calculated by finding the closest `lua` ancestor directory, and copying the entire tree from that root to the config directory.

        If a directory is specified, it will be recursively copied to the config directory, preserving the directory structure.
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

  config = lib.mkMerge [
    {
      wayland.windowManager.hyprland.custom-settings.lua.luaModules =
        builtins.readDir ./lua
        |> lib.filterAttrs (_: type: type == "regular")
        |> builtins.attrNames
        |> builtins.filter (file: builtins.match ".*\\.lua$" file != null)
        |> map (file: ./lua/${file})
        |> lib.mkBefore;
    }

    (mkIf cfg.enable {
      wayland.windowManager.hyprland = {
        extraLuaFiles =
          cfg.luaModules
          |> map (
            modulePath:
            nameValuePair (baseNameOf modulePath) {
              content = renderFile modulePath;
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

      xdg.configFile =
        if cfg.luaExtras != [ ] then
          let
            luaBase = findLuaAncestor (builtins.head cfg.luaExtras);
            processed = map (
              p:
              nameValuePair "hypr/${relPath luaBase p}" (
                if (pathIsDirectory p) then { source = p; } else { text = renderFile p; }
              )
            ) cfg.luaExtras;
          in
          listToAttrs processed
        else
          { };

    })
  ];
}
