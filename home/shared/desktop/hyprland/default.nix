{ flake, inputs, pkgs, ... }:
let inherit (pkgs) system; in {
  imports = [
    inputs.hyprland.homeManagerModules.default
    "${flake}/home/shared/desktop/common"
    "${flake}/home/shared/desktop/wayland"
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;

    package = inputs.hyprland.packages.${system}.hyprland;

    systemd.variables = [ "-all" ];
  };
}
