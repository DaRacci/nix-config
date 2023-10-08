{ pkgs, ... }: {
  home.packages = with pkgs; [
    inxi
    glxinfo
    xorg.xdpyinfo
    hyfetch
  ];
}
