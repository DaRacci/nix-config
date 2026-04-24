{
  anyoneHasPackage,
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
    mkMerge
    ;

  cfg = config.core.hm-helper;
  nautilusCfg = cfg.nautilus;
in
{
  options.core.hm-helper.nautilus = {
    enable = mkEnableOption "Enable Nautilus extensions and integration helpers." // {
      default = anyoneHasPackage pkgs.nautilus;
      defaultText = literalExpression "anyoneHasPackage pkgs.nautilus";
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && nautilusCfg.enable) {
      services.gnome.sushi.enable = true;
      environment.pathsToLink = [ "/share/nautilus-python/extensions" ];
    })
  ];
}
