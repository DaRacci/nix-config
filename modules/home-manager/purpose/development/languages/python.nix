{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.development.languages.jvm;
  rootCfg = config.purpose.development;
in
{
  options.purpose.development.languages.python = {
    enable = mkEnableOption "Enable Python Development";
  };

  config = mkIf (rootCfg.enable && cfg.enable) { };
}
