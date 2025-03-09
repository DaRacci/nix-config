{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ctop
    iotop-c
    sysstat
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
