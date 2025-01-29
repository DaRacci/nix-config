{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Processes Info
    lsof

    # System Info
    inxi
    pciutils
    glxinfo
    xorg.xdpyinfo
    hyfetch
  ];
}
