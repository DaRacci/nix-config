{ pkgs, ... }: {
  imports = [
    ./emacs
    ./jetbrains.nix
  ];

  home.packages = with pkgs; [ nix-init ];
}