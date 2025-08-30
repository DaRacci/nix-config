{
  lib,
  ...
}:
{
  wayland.windowManager.hyprland.settings = {
    misc = {
      vfr = true;
      vrr = 3;
    };

    xwayland = {
      enabled = true;
      use_nearest_neighbor = false;
      force_zero_scaling = true;
      create_abstract_socket = false;
    };

    experimental.xx_color_management_v4 = true;

    render = {
      direct_scanout = 2;

      cm_fs_passthrough = 2;
      cm_enabled = true;
      send_content_type = true;
      cm_auto_hdr = true;
    };

    monitor = lib.mkAfter [
      ", preferred, auto, 1" # Fallback Rule
    ];
  };
}
