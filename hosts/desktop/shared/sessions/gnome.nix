{ pkgs, lib, ... }:
let
  inherit (pkgs)
    gnome-calculator
    gnome-connections
    gnome-text-editor
    gnome-tour
    simple-scan
    yelp
    ;
in
{
  imports = [
    ./default.nix
  ];

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

  environment.gnome.excludePackages = [
    gnome-tour
    gnome-text-editor
    gnome-calculator
    gnome-connections
    simple-scan
    yelp
  ];
}
