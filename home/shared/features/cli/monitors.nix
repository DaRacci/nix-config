{ pkgs, ... }: {
  home.packages = with pkgs; [
    ctop
  ];

  programs.btop = {
    enable = true;
    package = pkgs.btop;
    settings = { };
  };

  programs.bottom = {
    enable = true;
    package = pkgs.bottom;
    settings = { };
  };
}
