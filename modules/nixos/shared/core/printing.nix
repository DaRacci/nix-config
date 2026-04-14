{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkMerge;
  cfg = config.custom.core;
in
{
  options.custom.core.printing = {
    enable = mkEnableOption "Enable printing support";
  };

  config = mkMerge [
    {
      custom.core.printing.enable = config.host.device.role != "server" && !config.host.device.isVirtual;
    }

    (mkIf (cfg.enable && cfg.printing.enable) {
      services.printing = {
        enable = true;
        drivers = [
          pkgs.hplip
          pkgs.gutenprint
          pkgs.gutenprint-bin
          pkgs.cups-filters
          pkgs.mfcl3770cdwlpr
          pkgs.mfcl3770cdwcupswrapper
        ];
      };

      custom.defaultGroups = [ "lp" ];
    })
  ];
}