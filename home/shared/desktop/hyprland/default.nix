{
  self,
  osConfig ? null,
  pkgs,
  ...
}:
{
  imports = [
    "${self}/home/shared/desktop/common"
    "${self}/home/shared/desktop/wayland"

    ./nvidia.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = if (osConfig != null) then osConfig.programs.hyprland.package else pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;

    xwayland.enable = true;
    systemd.enable = false;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    config = {
      Hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];

        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
  };
}
