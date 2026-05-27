{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption optionals;
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
      (optionals ((builtins.length cfg.screenCopy) > 0) (
        map (app: {
          _args = [
            app
            "screencopy"
            "allow"
          ];
        }) cfg.screenCopy
      ))
      ++ (optionals ((builtins.length cfg.plugin) > 0) (
        map (plugin: {
          _args = [
            plugin
            "plugin"
            "allow"
          ];
        }) cfg.plugin
      ));
  };
}
