{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nix-init
    cachix
  ];
}
