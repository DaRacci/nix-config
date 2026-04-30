{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.hardware.rgb;
in
{
  options.hardware.rgb = {
    enable = mkEnableOption "enable RGB support";
  };

  config = mkIf cfg.enable {
    services = {
      hardware.openrgb = {
        enable = true;
        motherboard = "amd";
        package = pkgs.openrgb-with-all-plugins;
      };
    };
  };
}
