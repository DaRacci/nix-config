{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.development.jvm;
in
{
  options.purpose.development.jvm = {
    enable = lib.mkEnableOption "Enable JVM Development";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ jetbrains.idea-community ];
  };
}
