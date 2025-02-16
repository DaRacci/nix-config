{
  flake,
  osConfig ? null,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.hyprland.homeManagerModules.default
    "${flake}/home/shared/desktop/common"
    "${flake}/home/shared/desktop/wayland"
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = if (osConfig != null) then osConfig.programs.hyprland.package else pkgs.hyprland;

    xwayland.enable = true;
    systemd = {
      enable = false;
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };
  };
}
