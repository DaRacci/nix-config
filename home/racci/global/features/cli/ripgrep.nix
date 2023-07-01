{ pkgs, ... }: {
  # programs.ripgrep.enable = true;
  home.packages = with pkgs; [ ripgrep ];
}