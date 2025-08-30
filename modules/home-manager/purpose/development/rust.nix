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
    rust-rover.enable = lib.mkEnableOption "Add the rust-rover package." // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf cfg.rust-rover.enable (with pkgs; [ jetbrains.rust-rover ]);
  };
}
