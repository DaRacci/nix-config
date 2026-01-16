{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.development.languages.rust;
  rootCfg = config.purpose.development;
in
{
  options.purpose.development.languages.rust = {
    enable = mkEnableOption "Enable Rust Development";
    rust-rover.enable = mkEnableOption "Add the rust-rover package.";
  };

  config = mkIf (rootCfg.enable && cfg.enable) {
    home.packages = lib.mkIf cfg.rust-rover.enable (with pkgs; [ jetbrains.rust-rover ]);
  };
}
