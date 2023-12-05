{ lib, config, ... }: with lib; let
  cfg = config.purposes;
in
{
  imports = [
    ./development.nix
  ];

  options.purposes = {
    enable = mkEnableOption "If purpose auto-configuration should happen.";
    default = true;
  };

  config = mkIf cfg.enable { };
}