{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption;
  cfg = config.wayland.windowManager.hyprland.custom-settings.permission;
in
{
  options.wayland.windowManager.hyprland.custom-settings.permission = {
    screenCopy = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of applications allowed to copy the screen.";
    };
    plugin = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of plugins that are allowed to run.";
    };
  };

  config = {
    wayland.windowManager.hyprland.settings.permission =
      (lib.optionals ((builtins.length cfg.screenCopy) > 0) (
        lib.map (app: "${app}, screencopy, allow") cfg.screenCopy
      ))
      ++ (lib.optionals ((builtins.length cfg.plugin) > 0) (
        lib.map (plugin: "${plugin}, plugin, allow") cfg.plugin
      ));
  };
}
