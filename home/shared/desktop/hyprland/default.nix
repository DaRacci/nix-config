{ flake, inputs, ... }: {
  imports = [
    inputs.hyprland.homeManagerModules.default
    "${flake}/home/shared/desktop/common"
    "${flake}/home/shared/desktop/wayland"
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
  };
}
