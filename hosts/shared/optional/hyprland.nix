{ inputs, pkgs, ... }: {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  };

  services.xserver.updateDbusEnvironment = true;
  security.pam.services.hyprland = {
    enableGnomeKeyring = true;
  };
}
