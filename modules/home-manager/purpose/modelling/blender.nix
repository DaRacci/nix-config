# TODO - Only install if satisfactory is installed on steam
# Provides a general area for modding packages,
# and their persistent directories.
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.purpose.modelling.blender;
in
{
  options.purpose.modelling.blender = {
    enable = mkEnableOption "enabled blender with cuda support";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ blender ];

    user.persistence.directories = [ ".config/blender" ];
  };
}
