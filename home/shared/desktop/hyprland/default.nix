{
  flake,
  osConfig,
  inputs,
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
    inherit (osConfig.programs.hyprland) package;

    xwayland.enable = true;
    systemd = {
      enable = false;
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };
  };
}
