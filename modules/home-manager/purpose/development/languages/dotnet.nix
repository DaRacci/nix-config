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
  options.purpose.development.languages.dotnet = {
    enable = mkEnableOption "Enable .NET Development, including PowerShell";
  };

  config = mkIf (rootCfg.enable && cfg.enable) {
    home.packages = with pkgs; [ powershell ];
  };
}
