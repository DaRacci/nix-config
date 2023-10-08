{ pkgs, ... }: {
  # programs.ripgrep = {
  #   enable = true;
  #   package = pkgs.ripgrep;

  #   arguments = [ ];
  # };

  home.packages = with pkgs.unstable; [ ripgrep ];
}
