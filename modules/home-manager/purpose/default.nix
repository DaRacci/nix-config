{ lib, config, ... }: with lib; let
  cfg = config.purposes;
in
{
  imports = [
    ./development
    ./gaming
    ./modelling
  ];

  options.purpose = {
    enable = mkEnableOption "If purpose auto-configuration should happen.";
  };

  config = mkIf cfg.enable { };
}
