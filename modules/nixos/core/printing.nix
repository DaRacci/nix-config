{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    ;
  cfg = config.core.printing;
in
{
  options.core.printing = {
    enable = mkEnableOption "printing support";
  };

  config = mkMerge [
    {
      core.printing.enable = mkDefault (
        config.host.device.role != "server" && !config.host.device.isVirtual
      );
    }

    (mkIf (config.core.enable && cfg.enable) {
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
