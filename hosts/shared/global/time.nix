{ config, lib, ... }:
{
  time = lib.mkIf (!config.host.device.isHeadless) {
    timeZone = "Australia/Sydney";
    hardwareClockInLocalTime = true;
  };
}
