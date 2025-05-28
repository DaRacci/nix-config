{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Processes Info
    lsof

    # System Info
    inxi
    pciutils
    xorg.xdpyinfo
    hyfetch
  ];
}
