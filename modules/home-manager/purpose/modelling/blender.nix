# TODO - Only install if satisfactory is installed on steam
# Provides a general area for modding packages,
# and their persistent directories.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (pkgs) blender;
  cfg = config.purpose.modelling.blender;
in
{
  options.purpose.modelling.blender = {
    enable = mkEnableOption "enabled blender with cuda support";
  };

  config = mkIf cfg.enable {
    home.packages = [ blender ];

    user.persistence.directories = [ ".config/blender" ];
  };
}
