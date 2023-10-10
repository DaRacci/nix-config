{ pkgs, ... }: {
  home.packages = with pkgs; [
    inxi
    pciutils
    glxinfo
    xorg.xdpyinfo
    hyfetch
  ];
}
