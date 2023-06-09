{ pkgs, ... }: {
  imports = [
    ./builder.nix
    ./code.nix
    ./emacs
    ./jetbrains.nix
    ./lapce.nix
  ];

  home.packages = with pkgs; [ nix-init ];

  home.persistence."/persist/home/racci".directories = [
    "Projects"
  ];
}