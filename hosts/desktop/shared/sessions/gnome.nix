{ pkgs, lib, ... }:
{
  programs.xwayland.enable = true;

  xdg.portal = {
    enable = lib.mkForce true;
    xdgOpenUsePortal = true;
  };

  services = {
    enable = true;

    displayManager.gdm = {
      enable = true;
      wayland = true;
    };

    desktopManager.gnome = {
      enable = true;
    };
  };

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-text-editor
    gnome-calculator
    gnome-connections
    simple-scan
    yelp
  ];
}
