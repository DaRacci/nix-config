_: {
  wayland.windowManager.hyprland = {
    settings.config = {
      cursor = {
        no_warps = false;
        persistent_warps = true;
        warp_back_after_non_mouse_input = false;

        no_hardware_cursors = true;
        use_cpu_buffer = 2;

        inactive_timeout = 15;
        hide_on_key_press = true;
      };

      binds = {
        workspace_back_and_forth = true;
        allow_workspace_cycles = true;
        workspace_center_on = 1;
        focus_preferred_method = 1;
        movefocus_cycles_fullscreen = false;
        allow_pin_fullscreen = true;
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;

        touchpad = {
          natural_scroll = false;
        };

        sensitivity = 0;
        accel_profile = "flat";
      };

      misc = {
        key_press_enables_dpms = false;
        mouse_move_enables_dpms = true;
      };
    };
  };
}
