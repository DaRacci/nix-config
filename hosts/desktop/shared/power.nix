{ lib, ... }:
{
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  powerManagement = {
    enable = lib.mkDefault true;
    cpuFreqGovernor = "ondemand";
  };
}
