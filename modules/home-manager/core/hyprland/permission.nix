{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    optionals
    types
    getExe
    ;
  inherit (types)
    listOf
    package
    str
    either
    ;
  cfg = config.wayland.windowManager.hyprland.custom-settings.permission;

  /*
    Hyprlands permissions need the absolute base path to the binary.
    If a program uses a wrapper script, it must instead target the `.<name>-wrapped` file.
  */
  getBinaryPath =
    package:
    let
      wrapperPath = "${package.outPath}/bin/.${package.meta.mainProgram or package.pname}-wrapped";
      isWrapper = builtins.pathExists wrapperPath;
      binaryPath = if isWrapper then wrapperPath else getExe package;
    in
    if builtins.isString package then package else binaryPath;

  getPluginPath =
    package: if builtins.isString package then package else "${package}/lib/lib${package.pname}.so";

  mkLuaPermission = type: binary: {
    inherit binary type;
    mode = "allow";
  };
in
{
  options.wayland.windowManager.hyprland.custom-settings.permission = {
    screenCopy = mkOption {
      type = listOf (either package str);
      default = [ ];
      description = "List of applications allowed to copy the screen.";
    };

    plugin = mkOption {
      type = listOf (either package str);
      default = [ ];
      description = "List of plugins that are allowed to run.";
    };
  };

  config = lib.mkIf config.wayland.windowManager.hyprland.enable {
    wayland.windowManager.hyprland.settings = {
      config.ecosystem.enforce_permissions = true;

      permission =
        (optionals (cfg.screenCopy != [ ]) (
          cfg.screenCopy |> map getBinaryPath |> map (mkLuaPermission "screencopy")
        ))
        ++ (optionals (cfg.plugin != [ ]) (
          cfg.plugin |> map getPluginPath |> map (mkLuaPermission "plugin")
        ));
    };
  };
}
