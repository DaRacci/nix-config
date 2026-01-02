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
  inherit (lib) mkIf;

  cfg = config.custom.hm-helpers;
  nautilusCfg = cfg.nautilus;
in
{
  options.custom.hm-helpers.nautilus = {
    enable = lib.mkEnableOption "Enable Nautilus extensions and integration helpers." // {
      default = anyoneHasPackage pkgs.nautilus;
    };
  };

  config = mkIf (cfg.enable && nautilusCfg.enable) {
    services.gnome.sushi.enable = true;
    environment.pathsToLink = [ "/share/nautilus-python/extensions" ];
  };
}
