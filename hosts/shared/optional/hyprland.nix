{ inputs, pkgs, lib, ... }: {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  hardware.opengl =
    let
      hyprland-packages = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.system};
    in
    {
      package = lib.mkOverride 50 hyprland-packages.mesa.drivers;

      # if you also want 32-bit support (e.g for Steam)
      driSupport32Bit = true;
      package32 = lib.mkOverride 50 hyprland-packages.pkgsi686Linux.mesa.drivers;
    };

  services = {
    xserver.updateDbusEnvironment = true;
    gnome.gnome-keyring.enable = true;
  };

  security.pam.services.hyprland = {
    enableGnomeKeyring = true;
  };

  # TODO - Move the HM when 24.05 is released
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];

    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
        ];

        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };

    wlr = {
      enable = false;
      settings = { };
    };
  };
}
