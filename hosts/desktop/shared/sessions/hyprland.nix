{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./default.nix
  ];

  programs = {
    uwsm.enable = true;
    hyprland = {
      enable = true;
      withUWSM = true;
      package = pkgs.hyprland;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };
  };

  services = {
    xserver.updateDbusEnvironment = true;
    gnome.gnome-keyring.enable = true;
  };

  security.pam.services = {
    hyprland.enableGnomeKeyring = true;
    hyprlock = { };
  };

  xdg.portal.enable = true;

  # Fix from https://github.com/hyprwm/Hyprland/issues/7704#issuecomment-2449563257
  # Also seems like it should be applied to more things:https://git.pika-os.com/wm-packages/pika-hyprland-settings/src/branch/main/pika-hyprland-settings/etc/nvidia/nvidia-application-profiles-rc.d/50-pika-hyprland.json
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
          {
            pattern = {
              feature = "procname";
              matches = "Discord";
            };
            profile = "Limit Free Buffer Pool On Wayland Compositors";
          }
          {
            pattern = {
              feature = "procname";
              matches = "Xwayland";
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
