{
  lib,
  ...
}:
{
  wayland.windowManager.hyprland.settings = {
    config = {
      misc = {
        vrr = 3;
      };

      xwayland = {
        enabled = true;
        use_nearest_neighbor = false;
        force_zero_scaling = true;
        create_abstract_socket = false;
      };

      render = {
        direct_scanout = 2;
        cm_enabled = true;
        send_content_type = true;
        cm_auto_hdr = true;
      };
    };

    monitor = lib.mkAfter [
      {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = 1;
      }
    ];
  };
}
