{ pkgs, ... }:
{
  home.packages = with pkgs; [
    resources
    mission-center
  ];
}
