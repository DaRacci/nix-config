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

  wayland.windowManager.hyprland = rec {
    enable = true;
    package = if (osConfig != null) then osConfig.programs.hyprland.package else pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;

    xwayland.enable = true;
    systemd.enable = false;

    settings = {
      permission = [
        "${portalPackage}/libexec/xdg-desktop-portal-hyprland, screencopy, allow"
      ];
    };
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
