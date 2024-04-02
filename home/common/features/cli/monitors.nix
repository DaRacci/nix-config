{ pkgs, ... }: {
  home.packages = with pkgs; [
    nvtop
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
