{
  flake,
  osConfig ? null,
  pkgs,
  ...
}:
{
  imports = [
    "${flake}/home/shared/desktop/common"
    "${flake}/home/shared/desktop/wayland"

    ./nvidia.nix
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
