{ pkgs, ... }: {
  imports = [
    ./jetbrains.nix
  ];

  home.packages = with pkgs; [ nix-init ];
}