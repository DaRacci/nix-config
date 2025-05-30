{ pkgs, ... }:
{
  home.packages = with pkgs; [
    resources
  ];
}
