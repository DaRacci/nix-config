{ config, lib }:

with lib; let
  hostname = config.networking.hostName;
in {
  options.hardware.encrypted-root = {
    enable = mkEnableOption "encrypted-root";
  };

  config = mkIf cfg.enable {
    boot.initrd = {
      luks.devices.${hostname}.device = "/dev/disk/by-label/${hostname}_crypt";
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ racci ];
  };
}
