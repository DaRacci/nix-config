{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.hardware.cooling;
in
{
  options.hardware.cooling = {
    enable = mkEnableOption "enable cooling support" // {
      default = config.host.device.role == "desktop";
    };
  };

  config = mkIf cfg.enable {
    programs.coolercontrol = {
      enable = true;
      nvidiaSupport = true;
    };

    host.persistence.directories = [
      "/etc/coolercontrol"
    ];
  };
}
