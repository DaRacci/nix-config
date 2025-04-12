{ pkgs, ... }:
{
  home.packages = with pkgs; [
    keypunch
    vial
  ];
}
