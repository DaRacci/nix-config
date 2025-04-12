{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ctop
    iotop-c
    sysstat
    nvtopPackages.full
  ];

  programs = {
    btop = {
      enable = true;
      package = pkgs.btop;
      settings = { };
    };

    bottom = {
      enable = true;
      package = pkgs.bottom;
      settings = { };
    };
  };
}
