{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.uwsm.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  hardware.graphics = {
    package = lib.mkDefault pkgs.mesa;
    package32 = lib.mkDefault pkgs.pkgsi686Linux.mesa;
    enable32Bit = true;
  };

  services = {
    xserver.updateDbusEnvironment = true;
    gnome.gnome-keyring.enable = true;
  };

  security.pam.services = {
    hyprland.enableGnomeKeyring = true;
    hyprlock = { };
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

  # Fix from https://github.com/hyprwm/Hyprland/issues/7704#issuecomment-2449563257
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json" =
    lib.mkIf config.hardware.graphics.hasNvidia {
      text = builtins.toJSON {
        rules = [
          {
            pattern = {
              feature = "procname";
              matches = "Hyprland";
            };
            profile = "Limit Free Buffer Pool On Wayland Compositors";
          }
          {
            pattern = {
              feature = "cmdline";
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
    };
}
