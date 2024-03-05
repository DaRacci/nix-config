{ inputs, ... }: {
  imports = [ inputs.hyprland.homeManagerModules.default ../wayland ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
  };
}
