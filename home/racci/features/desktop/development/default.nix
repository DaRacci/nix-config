{ pkgs, ... }: {
  imports = [
    # ./emacs
    ./code.nix
    ./jetbrains.nix
    # ./lapce.nix
  ];

  home.packages = with pkgs; [ nix-init ];

  home.persistence."/persist/home/racci".directories = [
    "Projects"
  ];
}
