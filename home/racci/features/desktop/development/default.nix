{ pkgs, ... }: {
  imports = [
    # ./emacs
    ./code.nix
    ./jetbrains.nix
    # ./lapce.nix
  ];

  home.packages = with pkgs; [ nix-init ];

  user.persistence.directories = [
    "Projects"
  ];
}
