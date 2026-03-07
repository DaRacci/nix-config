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
  inherit (lib) mkIf mkMerge literalExpression;

  cfg = config.custom.hm-helper;
  nautilusCfg = cfg.nautilus;
in
{
  options.custom.hm-helper.nautilus = {
    enable = lib.mkEnableOption "Enable Nautilus extensions and integration helpers." // {
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
