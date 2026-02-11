{ config, lib, ... }:
let
  inherit (lib) mkIf mkMerge mkEnableOption;
  inherit (config.host) device;

  cfg = config.hardware.cooling;
in
{
  options.hardware.cooling = {
    enable = mkEnableOption "enable cooling support";
  };

  config = mkMerge [
    {
      hardware.cooling = device.role == "desktop" && !device.isVirtual;
    }

    (mkIf cfg.enable {
      programs.coolercontrol = {
        enable = true;
        nvidiaSupport = config.hardware.graphics.hasNvidia;
      };

      host.persistence.directories = [ "/etc/coolercontrol" ];
    })
  ];
}
