{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.purpose;
in
{
  imports = [
    ./development
    ./diy
    ./gaming
    ./modelling
  ];

  options.purpose = {
    enable = mkEnableOption "If purpose auto-configuration should happen.";
  };

  config = mkIf cfg.enable { };
}
