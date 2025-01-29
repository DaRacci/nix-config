{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.development.rust;
in
{
  options.purpose.development.rust = {
    enable = lib.mkEnableOption "Enable Rust Development";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ jetbrains.rust-rover ];
  };
}
