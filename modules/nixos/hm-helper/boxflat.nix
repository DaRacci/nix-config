{
  anyoneHasPackage,
  usersWithPackage,
  ...
}:
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

  cfg = config.core.hm-helper;
in
{
  options.core.hm-helper.boxflat = {
    enableUdevRules = mkEnableOption "Boxflat udev rules" // {
      default = anyoneHasPackage pkgs.boxflat;
      defaultText = literalExpression "anyoneHasPackage pkgs.boxflat";
    };
  };

  config = mkIf (cfg.enable && cfg.boxflat.enableUdevRules) {
    services.udev.packages = [ pkgs.boxflat ];
  };
}
