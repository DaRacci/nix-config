{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.hardware.cooling;
  inherit (config.host) device;
in
{
  options.hardware.cooling = {
    enable = mkEnableOption "enable cooling support" // {
      default = device.role == "desktop" && !device.isVirtual;
    };
  };

  config = mkIf cfg.enable {
    programs.coolercontrol = {
      enable = true;
      nvidiaSupport = config.hardware.graphics.hasNvidia;
    };

    host.persistence.directories = [ "/etc/coolercontrol" ];
  };
}
