{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland.override {
      enableXWayland = true;
      withSystemd = true;
    };

    xwayland.enable = true;
    portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  hardware.graphics =
    let
      hyprland-packages = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.system};
    in
    {
      package = lib.mkOverride 50 hyprland-packages.mesa.drivers;
      package32 = lib.mkOverride 50 hyprland-packages.pkgsi686Linux.mesa.drivers;
      enable32Bit = true;
    };

  services = {
    xserver.updateDbusEnvironment = true;
    gnome.gnome-keyring.enable = true;
  };

  security.pam.services.hyprland = {
    enableGnomeKeyring = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];

    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
        ];

        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };

    wlr = {
      enable = false;
      settings = { };
    };
  };

  # Fix from https://github.com/hyprwm/Hyprland/issues/7704#issuecomment-2449563257
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "Hyprland";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 1;
            }
          ];
        }
      ];
    };
}
