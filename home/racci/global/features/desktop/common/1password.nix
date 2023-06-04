{ pkgs, ...}: {
  home.packages = with pkgs; [
    _1password
    _1password-gui
  ];
}