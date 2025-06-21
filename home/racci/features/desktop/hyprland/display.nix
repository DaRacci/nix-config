{
  lib,
  ...
}:
{
  wayland.windowManager.hyprland.settings = {
    experimental.xx_color_management_v4 = true;

    render = {
      explicit_sync = 2;
      explicit_sync_kms = 2;
      direct_scanout = 2;

      cm_fs_passthrough = 2;
      cm_enabled = true;
      send_content_type = true;
    };

    monitor = lib.mkAfter [
      ", preferred, auto, 1" # Fallback Rule
    ];
  };
}
