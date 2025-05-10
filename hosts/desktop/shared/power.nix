{ lib, ... }:
{
  services.upower.enable = lib.mkDefault true;
  services.power-profiles-daemon.enable = lib.mkDefault true;

  powerManagement = {
    enable = lib.mkDefault true;
    cpuFreqGovernor = "ondemand";
  };
}
