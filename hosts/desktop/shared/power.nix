_: {
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";
  };
}
