{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.development.languages.jvm;
  rootCfg = config.purpose.development;
in
{
  options.purpose.development.languages.jvm = {
    enable = mkEnableOption "Enable JVM Development";
  };

  config = mkIf (rootCfg.enable && cfg.enable) {
    home.packages = with pkgs; [ jetbrains.idea-community ];
  };
}
