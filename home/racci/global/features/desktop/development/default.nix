{ pkgs, ... }: {
  imports = [
    ./emacs
    ./jetbrains.nix
    ./lapce.nix
  ];

  home.packages = with pkgs; [ nix-init ];
}