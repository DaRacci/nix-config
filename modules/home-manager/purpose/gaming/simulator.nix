{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.gaming.simulator;
in
{
  options.purpose.gaming.simulator = {
    enable = lib.mkEnableOption "Enable simulator support";
    enableRacing = lib.mkEnableOption "Enable Moza Racing";
  };

  config = lib.mkIf (cfg.enable && cfg.enableRacing) {
    home.packages = with pkgs; [ boxflat ];

    user.persistence.directories = [ ".config/boxflat" ];
  };
}
