{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    ;
  cfg = config.core.printing;
in
{
  options.core.printing = {
    enable = mkEnableOption "printing support" // {
      default = config.host.device.role != "server" && !config.host.device.isVirtual;
      defaultText = literalExpression ''config.host.device.role != "server" && !config.host.device.isVirtual'';
    };
  };

  config = mkIf (config.core.enable && cfg.enable) {
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

    core.defaultGroups = [ "lp" ];
  };
}
